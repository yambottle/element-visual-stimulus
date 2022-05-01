function obj = getSchema
persistent schemaObject
if isempty(schemaObject)
    schemaName = 'stim';
    schemaObject = dj.Schema(dj.conn, 'stimulus', schemaName);
end
obj = schemaObject;
end
