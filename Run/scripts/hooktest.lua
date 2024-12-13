local DHook = require("GCC/Lib/discohook")

local hook =
    DHook.create(
    "https://discord.com/api/webhooks/1317077071863742504/3z9krO8cJfi778veJtniXPBEQ1-8gPJAxpsekzuZTNBWC7_tY4bijIyiXINCqCWO-QuU"
)

hook:sendMessage("Hello!\n-- Send from my Pocket Phone")
