local GLogAble = require("GCC/Util/glog")
local f = string.format

---@class GState : GLogAble
local GState = {}

---@class GState.StateMachine.Options : GLogAble.Options
---@field initialState GState.STATE? Default: INIT

---@class GState.StateMachine : GLogAble
---@overload fun(options: GState.StateMachine.Options) : GState.StateMachine
GState.StateMachine = GLogAble:extend()

---@enum GState.STATE
GState.STATE = {
    INIT = "INIT",
    EXIT = "EXIT"
}

---@param ... any
---@return GState.STATE state
---@return table stateArgs
local function extractStateArgs(...)
    local varargs = {...}
    local state = varargs[1]
    local stateArgs = {}
    for i = 2, #varargs do
        table.insert(stateArgs, varargs[i])
    end
    return state, stateArgs
end

---@param options GState.StateMachine.Options
function GState.StateMachine:new(options)
    options = options or {}
    ---@diagnostic disable-next-line: redundant-parameter
    GState.StateMachine.super.new(self, options)

    ---@type GState.STATE?
    self.interruptState = nil
    self.interruptStateArgs = nil

    ---@type GState.STATE
    self.state = nil
    self.stateArgs = {}

    self:SetState(options.initialState or GState.STATE.INIT, {})
end

---@param ... any
function GState.StateMachine:Interrupt(...)
    self.interruptState, self.stateArgs = extractStateArgs(...)
end

function GState.StateMachine:Run()
    repeat
        local stateFunc = self[self.state] --[[@as function]]
        if not stateFunc or type(stateFunc) ~= "function" then
            return
        end
    until stateFunc(self, table.unpack(self.stateArgs)) == false -- nil should continue
end

function GState.StateMachine:SetState(...)
    local logMsg = f("State Transfer: [%s] -> ", self.state)
    local state, stateArgs = extractStateArgs(...)
    if self.interruptState then
        self.state = self.interruptState
        self.stateArgs = self.interruptStateArgs
        self.interruptState = nil
        self.interruptStateArgs = nil
    else
        self.state = state
        self.stateArgs = stateArgs
    end
    self:FLog("%s -> [%s]", logMsg, self.state)
end

function GState.StateMachine:INIT()
    self:SetState(GState.STATE.EXIT)
end

function GState.StateMachine:EXIT()
    return false
end

return GState
