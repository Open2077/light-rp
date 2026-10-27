-- Public item names and model-independent dimensions; money stays server-owned.
for kind,spec in pairs({
 roulette={item="roulette_table",label="Roulette Table",size=1},
 dominoes={item="dominoes_set",label="Dominoes Set",size=1},
 cardtower={item="cardtower_set",label="Card Tower Set",size=1},
}) do
 LightRpBoardGames[kind]=spec
 LightRpItems[spec.item]={label=spec.label,description="Use to place the table. E: play; target menu: pick up your table.",weight=kind=="roulette" and 5 or 1.5,stack=1,icon="package",category="misc"}
end
