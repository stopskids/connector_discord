CreateThread(function()
    while true do
        if NetworkIsPlayerActive(PlayerId()) then
            Wait(1000)
            TriggerServerEvent('connector_discord:server:playerConnected')
            break
        end
        Wait(100)
    end
end)