-- =====================================
-- BRIDGE INITIALIZATION
-- Auto-detects framework at runtime
-- =====================================

Bridge = Bridge or {}

local function DetectFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    end
    return 'standalone'
end

Bridge.Framework = DetectFramework()

if Bridge.Framework == 'standalone' then
    print('[dps-cityworker] ^1WARNING: No supported framework detected!^0')
    print('[dps-cityworker] Supported: qb-core, qbx_core, es_extended')
else
    print(('[dps-cityworker] ^2Detected framework: %s^0'):format(Bridge.Framework))
end
