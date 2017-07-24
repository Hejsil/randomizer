import(
	"os.odin";
	"fmt.odin";
);

import(
	"nds.odin";
	"buffer.odin";
);


proc print_data_as_str(arr: []u8) {
	for c in arr { fmt.print(rune(c)); }
}

proc print_indent(i: int) {
	for p in 0..<i*2 {
		fmt.print(" ");
	}
}

proc print_folder(folder: nds.Folder, i: int = 0) {
	print_indent(i); fmt.println("{");
	i++;
	print_indent(i); fmt.println("folder");
	print_indent(i); fmt.println("id =", folder.id);
	print_indent(i); fmt.println("name =", folder.name);

	if len(folder.files) > 0 {
		print_indent(i); fmt.println("files = [");
		i++;

		for f in folder.files {
			print_indent(i); fmt.println("{");
			i++;

			print_indent(i); fmt.println("file");
			print_indent(i); fmt.println("id =", f.id);
			print_indent(i); fmt.println("size =", f.size);
			print_indent(i); fmt.println("offset =", f.offset);
			print_indent(i); fmt.println("name =", f.name); 

			i--;
			print_indent(i); fmt.println("}");
		}

		i--;
		print_indent(i); fmt.println("]");
	}

	if len(folder.folders) > 0 {
		print_indent(i); fmt.println("folders = [");
		i++;

		for f in folder.folders {
			print_folder(f, i);
		}

		i--;
		print_indent(i); fmt.println("]");
	}
	
	i--;
	print_indent(i); fmt.println("}");
}

proc print_pokemon(pokemon: nds.Pokemon) {
	fmt.println("Pokemon {");
	fmt.println("	hp =", pokemon.hp^);
	fmt.println("	attack =", pokemon.attack^);
	fmt.println("	defense =", pokemon.defense^);
	fmt.println("	speed =", pokemon.speed^);
	fmt.println("	sp_attack =", pokemon.sp_attack^);
	fmt.println("	sp_defense =", pokemon.sp_defense^);
	fmt.println("	type1 =", pokemon.type1^);
	fmt.println("	type2 =", pokemon.type2^);
	fmt.println("	catch_rate =", pokemon.catch_rate^);
	fmt.println("	common_held =", pokemon.common_held^);
	fmt.println("	rare_held =", pokemon.rare_held^);
	fmt.println("	dark_grass_held =", pokemon.dark_grass_held^);
	fmt.println("	exp_curve =", pokemon.exp_curve^);
	fmt.println("	ability1 =", pokemon.ability1^);
	fmt.println("	ability2 =", pokemon.ability2^);
	fmt.println("	ability3 =", pokemon.ability3^);
	fmt.println("}");
}

proc main() {
	var rom, success = nds.read_rom("D:\\Mega\\ProgramDataDump\\RandomizerSettings\\PokemonBlack2.nds");
	//defer free(rom);

	if success {
		var pokemons = nds.get_pokemons(rom);
		print_pokemon(pokemons[43]);
		fmt.println(len(pokemons));
		//fmt.println(os.write_entire_file("D:\\Mega\\ProgramDataDump\\RandomizerSettings\\Stench.nds", rom.data));
	}
}

