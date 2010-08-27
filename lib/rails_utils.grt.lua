--
-- Workbench Utility Plugins
--

-- ASSUMPTIONS:
--  1 All tables have a single column primary key called id
--
--
-- standard module/plugin functions
-- 

function getModuleInfo()
	return {
		name= "WbRailsUtils",
		author= "Mark Chapman",
		version= "0.1",
		implements= "PluginInterface",
		functions= {
		"getPluginInfo:l<o@app.Plugin>:",
		"copyRailsStructureToClipboard:i:o@db.Catalog"
		}
	}
end


-- helper function to create a descriptor for an argument of a specific type of object
function objectPluginInput(type)
	return grtV.newObj("app.PluginObjectInput", {objectStructName= type})
end

function getPluginInfo()
	local l
    local plugin

    -- create the list of plugins that this module exports
	l= new_plugin_list()

    plugin= new_plugin({
		name= "wb.rails.util.copyRailsStructureToClipboard",
        caption= "Copy Rails Structure to Clipboard",
		moduleName= "WbRailsUtils",
		pluginType= "normal", 
		moduleFunctionName= "copyRailsStructureToClipboard",
		inputValues= {objectPluginInput("db.Catalog")},
		groups= {"Catalog/Utilities", "Menu/Catalog"}
	})

    -- add to the list of plugins
    grtV.insert(l, plugin)

	return l
end

--    
-- implementation
--

function copyRailsStructureToClipboard(cat)

    local i, j, k, schema, tbl, col, fk
    local insert = ""
    local c_separator
    
    for i = 1, grtV.getn(cat.schemata) do
        schema = cat.schemata[i]
--      Process tables        
        for j = 1, grtV.getn(schema.tables) do
            tbl = schema.tables[j]
            insert = insert .. tbl.name .. ":"
	    c_separator = ""
--          Process columns in the table
            for k = 1, grtV.getn(tbl.columns) do
                col = tbl.columns[k]
                insert = insert .. c_separator .. col.name .. "," .. col.formattedType .. "," .. col.length .. ","
		insert = insert .. col.precision .. "," .. col.scale .. "," .. col.isNotNull
                c_separator = "#"
            end
--          Process foreign keys
            insert = insert .. ":"
	    c_separator = ""
            for k = 1, grtV.getn(tbl.foreignKeys) do
                fk = tbl.foreignKeys[k]
                insert = insert .. c_separator .. fk.referencedTable.name .. "," .. fk.many .. "," .. fk.mandatory
                c_separator = "#"
            end
            insert = insert .. "\n"
        end
    end
    
    Workbench:copyToClipboard(insert)

return 0
end


