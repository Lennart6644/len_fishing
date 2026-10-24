Locales = {}

function L(path, ...)
    local node = Locales[Config.Locale] or Locales.en
    for part in string.gmatch(path, '[^%.]+') do
        if type(node) ~= 'table' then
            return path
        end
        node = node[part]
    end
    if type(node) ~= 'string' then
        return path
    end
    if select('#', ...) > 0 then
        return string.format(node, ...)
    end
    return node
end
