%%
function messageTemplate = msgTemplate( msgType )
msgNo = EnsureNumericMessageType(msgType);
messageTemplate = GetMDF_by_MT(msgNo);
end