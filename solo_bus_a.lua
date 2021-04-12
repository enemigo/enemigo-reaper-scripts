--[[
 * ReaScript Name: Select A BUS
 * Description: Select track name by SublimeText-esque substring match.  Use the companion "Next" script
                to advance to next match.
 * Author: Jason Tackaberry (tack)
 * Licence: Public Domain
 * Extensions: SWS/S&M 2.8.0
 * Version: 1.0
 * Original: https://gist.github.com/jtackaberry/da3e192c560fd2b02b93709360ffe5b5
--]]

INSTRUMENT_TRACKS_ONLY = false

function focusTrack(track, multiselect)
    if multiselect == "1" or multiselect == true then
        reaper.SetTrackSelected(track, true)
    else
        reaper.SetOnlyTrackSelected(track)
    end
    
   -- reaper.Main_OnCommand(7, 0 ) -- solo selected
   -- reaper.Main_OnCommand(40340, 0 )  -- Track: Unsolo all tracks
   
    reaper.SetMixerScroll(track)
    -- Track: Set first selected track as last touched track.
    reaper.Main_OnCommandEx(40914, 0, 0)
    -- Track: Vertical scroll selected tracks into view.
    reaper.Main_OnCommandEx(40913, 0, 0)
end



function isInstrumentTrack(track)
    -- Iterate over all FX and look for FX names prefixed with
    -- "VSTi:".  We can't use TrackFX_GetInstrument because it skips
    -- offlined instruments.
    for fxIdx = 0, reaper.TrackFX_GetCount(track) - 1 do
        r, name = reaper.TrackFX_GetFXName(track, fxIdx, "")
        if string.sub(name, 0, 5) == "VSTi:" then
            return true
        end
    end
    return false
end

function getScore(track, term)
    local termPos = 1
    local lastMatchPos = 0
    local score = 0
    local match = false
    local instrument = isInstrumentTrack(track)
    local enabled = reaper.GetMediaTrackInfo_Value(track, "I_FXEN") > 0

    if term:sub(1, 1) == '/' then
        if not enabled then
            return 0
        end
        term = term:sub(2, #term)
    end

    if not instrument and INSTRUMENT_TRACKS_ONLY then
        return 0
    end

    local termCh = term:sub(termPos, termPos):lower()
    local name, flags = reaper.GetTrackState(track)
    visible = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
    if visible == 0 then
        return 0
    end

    for namePos = 1, #name do
        local nameCh = name:sub(namePos, namePos):lower()
        if nameCh == termCh then
            if lastMatchPos > 0 then
                local distance = namePos - lastMatchPos
                score = score + (100 - distance)
            end
            if termPos == #term then
                -- We have matched all characters in the term
                match = true
                break
            else
                lastMatchPos = namePos
                termPos = termPos + 1
                termCh = term:sub(termPos, termPos):lower()
            end
        end
    end
    if not match then
        return 0
    else
        -- Add 0.1 if this is an instrument track.
        if instrument then
            score = score + 0.1
        end
        -- Add another 0.1 if the track is enabled
        if reaper.GetMediaTrackInfo_Value(track, "I_FXEN") > 0 then
            score = score + 0.1
        end
        -- reaper.ShowConsoleMsg(name .. " -- " .. score .. "\n")
        return score
    end
end

function main()
    --r, term = reaper.GetUserInputs("Select track", 1, "Track name", "")
    --r, term = reaper.GetUserInputs("Select track", 1, "Track name", "")
    --r, 
    term="A"
    
   -- reaper.ShowConsoleMsg("term: "..term)
    if #term == 0 or not term then
        return
    end

    local matches = nil
    local bestScore = 0
    local bestTrack = nil
    local bestTrackIdx = nil

    for trackIdx = 0, reaper.CountTracks(0) - 1 do
        track = reaper.GetTrack(0, trackIdx)
        score = getScore(track, term)
        if score > 0 then
            if score > bestScore then
                bestScore = score
                bestTrack = track
                
                bestTrackIdx = trackIdx
            end
            local result = trackIdx .. "/" .. score
            if matches then
                matches = matches .. " " .. result
            else
                matches = result
            end
        end
    end
    if bestTrack then
       -- focusTrack(bestTrack, false)
        reaper.SetOnlyTrackSelected(bestTrack)
        reaper.Main_OnCommand( 40281,0)
        
    end
    reaper.SetExtState("select_track_by_name", "matches", matches or "", false)
    reaper.SetExtState("select_track_by_name", "current", bestTrackIdx or "", false)
end

reaper.defer(main)