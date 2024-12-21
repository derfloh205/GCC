local GAuth = require("GCC/GAuth/gauth")
local GVector = require("GCC/GNav/gvector")

---@class DoorAuthClient : GAuth.AuthClient
---@overload fun(options: GAuth.AuthClient.Options) : DoorAuthClient
local DoorAuthClient = GAuth.AuthClient:extend()

DoorAuthClient.BROADCAST_INTERVAL = 1
DoorAuthClient.BROADCAST_TIMEOUT = 2
function DoorAuthClient:Run()
    while true do
        self.position = GVector:FromGPS()
        if self.position then
            term.clear()
            term.setCursorPos(1, 1)
            print("Broadcasting to nearby doors...")
            local response =
                self:BroadcastAuthenticationRequest(
                self.id,
                self.username,
                self.position,
                DoorAuthClient.BROADCAST_TIMEOUT
            )
            if response and response.success then
                print("Authenticated!")
                sleep(1)
                term.clear()
                term.setCursorPos(1, 1)
            end
            sleep(DoorAuthClient.BROADCAST_INTERVAL)
        end
    end
end

return DoorAuthClient
