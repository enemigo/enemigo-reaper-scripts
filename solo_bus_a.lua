--[[
 * ReaScript Name: Toggle Select A BUS
 * Description: Hace toggle en la pista cuyo nombre contenga "A" (bus).
 * Author: Jason Tackaberry (tack) / Modificado por Patricio
 * Licence: Public Domain
 * Extensions: SWS/S&M 2.8.0
 * Version: 1.2
--]]

INSTRUMENT_TRACKS_ONLY = false

function toggleTrackSelection(track)
    if reaper.IsTrackSelected(track) then
        reaper.SetTrackSelected(track, false)
    else
        reaper.SetOnlyTrackSelected(track)
        reaper.SetMixerScroll(track)
        reaper.Main_OnCommandEx(40914, 0, 0)  -- Establece la pista como la última tocada.
        reaper.Main_OnCommandEx(40913, 0, 0)  -- Hace scroll vertical de la pista a la vista.
    end
end

function isInstrumentTrack(track)
    for fxIdx = 0, reaper.TrackFX_GetCount(track) - 1 do
        local ret, fxName = reaper.TrackFX_GetFXName(track, fxIdx, "")
        if string.sub(fxName, 1, 5) == "VSTi:" then
            return true
        end
    end
    return false
end

function getScore(track, term)
    local termPos = 1
    local lastMatchPos = 0
    local score = 0
    local instrument = isInstrumentTrack(track)
    local enabled = reaper.GetMediaTrackInfo_Value(track, "I_FXEN") > 0

    if term:sub(1, 1) == '/' then
        if not enabled then
            return 0
        end
        term = term:sub(2)
    end

    if not instrument and INSTRUMENT_TRACKS_ONLY then
        return 0
    end

    local termCh = term:sub(termPos, termPos):lower()
    local retval, name = reaper.GetTrackName(track, "")
    local visible = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
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
                score = score + (instrument and 0.1 or 0)
                score = score + (enabled and 0.1 or 0)
                return score
            else
                lastMatchPos = namePos
                termPos = termPos + 1
                termCh = term:sub(termPos, termPos):lower()
            end
        end
    end
    return 0
end

function main()
    local term = "A"
    if #term == 0 then return end

    local matches = ""
    local bestScore = 0
    local bestTrack = nil
    local bestTrackIdx = nil

    for trackIdx = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, trackIdx)
        local score = getScore(track, term)
        if score > bestScore then
            bestScore = score
            bestTrack = track
            bestTrackIdx = trackIdx
        end
        matches = matches .. (matches ~= "" and " " or "") .. trackIdx .. "/" .. score
    end

    if bestTrack then
        toggleTrackSelection(bestTrack)
    end

    reaper.SetExtState("select_track_by_name", "matches", matches, false)
    reaper.SetExtState("select_track_by_name", "current", bestTrackIdx or "", false)
end

reaper.defer(main)
