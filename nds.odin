import(
	"os.odin";
	"mem.odin";
	"math.odin";
	"sys/windows.odin";
);

import(
	"nds.odin";
	"buffer.odin";
	"crc.odin";
);

type Rom struct {
	data: []u8,
	header: Header,
	banner: Banner,
	fat: FAT,
	root_folder: Folder
}

type Header struct {
	game_title: [12]u8,
	game_code: [4]u8,
	maker_code: [2]u8,
	unit_code, encryption_seed: u8,
	tamano: u32, // ??
	reserved: [9]u8,
	rom_version, internal_flags: u8,
	arm9_rom_offset, arm9_entry_address, arm9_ram_address, amr9_size: u32,
	arm7_rom_offset, arm7_entry_address, arm7_ram_address, arm7_size: u32,
	fnt_offset, fnt_size: u32,
	fat_offset, fat_size: u32,
	arm9_overlay_offset, arm9_overlay_size: u32,
	arm7_overlay_offset, arm7_overlay_size: u32,
	flags_read, flags_init: u32,
	banner_offset: u32,
	secure_crc16: u16,
	rom_timeout: u16,
	arm9_autoload: u32,
	arm7_autoload: u32,
	secure_disable: u64,
	rom_size: u32,
	header_size: u32,
	reserved2: [56]u8,
	logo: [156]u8,
	logo_crc16, header_crc16: u16,
	secure_crc, logo_crc, header_crc: bool,
	debug_rom_offset, debug_size, debug_ram_address: u32,
	reserved3: u32,
	// reserved4: [0x90]u8
}

type Banner struct {
	version, crc16: u16,
	check_crc: bool,
	reserved: [28]u8,
	tile_data: [512]u8,
	palette: [32]u8,
	japanese_title, english_title, french_title: [256]u8, 
	german_title, italian_title, spanish_title: [256]u8,
}


type File_Allocation struct {
	size, offset: u32
}

type FAT struct {
	files: []File_Allocation
}

type File struct {
	data: []u8,
	offset, size: u32,
	name: string, // NOTE: Heap!
	id: u16
}

type Folder struct {
	files: [dynamic]File, // NOTE: Heap!
	folders: [dynamic]Folder, // NOTE: Heap!
	name: string, // NOTE: Heap!
	id: u16
}

type MainFNT struct {
	offset: u32,
	first_file_id: u16,
	parent_id: u16,
	sub_table: Folder
}

proc read_rom(path: string) -> (Rom, bool) {
	var result = Rom{};

	var data, success = os.read_entire_file(path /* "D:\\Mega\\ProgramDataDump\\RandomizerSettings\\PokemonBlack2.nds" */);

	if success {
		result.data = data;
		result.header = read_header(data);
		result.banner = read_banner(data, result.header.banner_offset);
		result.fat = read_fat(data, result.header.fat_offset, result.header.fat_size);
		result.root_folder = read_files(data, result.header.fnt_offset, result.fat);
	}

	return result, success;
}

proc read_header(rom: []u8) -> Header {
	var reader = buffer.Buffer_Reader{ data = rom, offset = 0 };
	var result = Header{};

	{
		using result;

		buffer.read(&reader, game_title[..]);
		buffer.read(&reader, game_code[..]);
		buffer.read(&reader, maker_code[..]);

		unit_code 		= buffer.read_u8(&reader);
		encryption_seed = buffer.read_u8(&reader);
		tamano 			= u32(math.pow(2, f64(17 + buffer.read_u8(&reader))));

		buffer.read(&reader, reserved[..]);

		rom_version     = buffer.read_u8(&reader);
		internal_flags  = buffer.read_u8(&reader);

		arm9_rom_offset = buffer.read_u32(&reader);
		arm9_entry_address = buffer.read_u32(&reader);
		arm9_ram_address = buffer.read_u32(&reader);
		amr9_size = buffer.read_u32(&reader);

		arm7_rom_offset = buffer.read_u32(&reader);
		arm7_entry_address = buffer.read_u32(&reader);
		arm7_ram_address = buffer.read_u32(&reader);
		arm7_size = buffer.read_u32(&reader);

		fnt_offset = buffer.read_u32(&reader);
		fnt_size = buffer.read_u32(&reader);

		fat_offset = buffer.read_u32(&reader);
		fat_size = buffer.read_u32(&reader);

		arm9_overlay_offset = buffer.read_u32(&reader);
		arm9_overlay_size = buffer.read_u32(&reader);

		arm7_overlay_offset = buffer.read_u32(&reader);
		arm7_overlay_size = buffer.read_u32(&reader);

		flags_read = buffer.read_u32(&reader);
		flags_init = buffer.read_u32(&reader);

		banner_offset = buffer.read_u32(&reader);

		secure_crc16 = buffer.read_u16(&reader);
		rom_timeout = buffer.read_u16(&reader);

		arm9_autoload = buffer.read_u32(&reader);
		arm7_autoload = buffer.read_u32(&reader);

		secure_disable = buffer.read_u64(&reader);

		rom_size = buffer.read_u32(&reader);

		header_size = buffer.read_u32(&reader);

		buffer.read(&reader, reserved2[..]);
		buffer.read(&reader, logo[..]);

		logo_crc16 = buffer.read_u16(&reader);
		header_crc16 = buffer.read_u16(&reader);

		debug_rom_offset = buffer.read_u32(&reader);
		debug_size = buffer.read_u32(&reader);
		debug_ram_address = buffer.read_u32(&reader);
		reserved3 = buffer.read_u32(&reader);

		{
			var secure_crc_data: [0x4000]u8;
			reader.offset = 0x4000;
			buffer.read(&reader, secure_crc_data[..]);
			secure_crc = crc.calculate16(secure_crc_data[..]) == u32(secure_crc16);
		}
		{
			var logo_crc_data: [156]u8;
			reader.offset = 0xC0;
			buffer.read(&reader, logo_crc_data[..]);
			logo_crc = crc.calculate16(logo_crc_data[..]) == u32(logo_crc16);
		}
		{
			var header_crc_data: [0x15E]u8;
			reader.offset = 0x0;
			buffer.read(&reader, header_crc_data[..]);
			header_crc = crc.calculate16(header_crc_data[..]) == u32(header_crc16);
		}

	}

	return result;
}

proc read_banner(rom: []u8, offset: u32) -> Banner {
	var reader = buffer.Buffer_Reader{ data = rom, offset = u64(offset) };
	var result = Banner{};

	{
		using result;

		version = buffer.read_u16(&reader);
		crc16 = buffer.read_u16(&reader);

		buffer.read(&reader, reserved[..]);
		buffer.read(&reader, tile_data[..]);
		buffer.read(&reader, palette[..]);
		buffer.read(&reader, japanese_title[..]);
		buffer.read(&reader, english_title[..]);
		buffer.read(&reader, french_title[..]);
		buffer.read(&reader, german_title[..]);
		buffer.read(&reader, italian_title[..]);
		buffer.read(&reader, spanish_title[..]);

		var check_crc_data: [0x820]u8;
		reader.offset = u64(offset) + 0x20;
		buffer.read(&reader, check_crc_data[..]);
		check_crc = crc.calculate16(check_crc_data[..]) == u32(crc16);
	}

	return result;
}

proc read_fat(rom: []u8, offset, size: u32) -> FAT {
	var reader = buffer.Buffer_Reader{ data = rom, offset = u64(offset) };
	var fat = FAT{ files = make([]File_Allocation, size / 0x08) };

	{
		using fat;
		for i in 0..<len(files) {
			files[i].offset = buffer.read_u32(&reader);
			files[i].size = buffer.read_u32(&reader) - files[i].offset;
		}
	}

	return fat;
}


proc read_files(rom: []u8, fnt_offset: u32, fat: FAT) -> Folder {
	var reader = buffer.Buffer_Reader{ data = rom, offset = u64(fnt_offset) };
	var mains = [dynamic]MainFNT;

	reader.offset += 6;
	var folder_count = buffer.read_u16(&reader);
	reader.offset = u64(fnt_offset);

	for i in 0..<folder_count {
		var main = MainFNT{
			offset = buffer.read_u32(&reader),
			first_file_id = buffer.read_u16(&reader),
			parent_id = buffer.read_u16(&reader)
		};

		var current_offset = reader.offset;
		reader.offset = u64(fnt_offset) + u64(main.offset);

		var id = buffer.read_u8(&reader);
		var next_id = main.first_file_id;

		for id != 0x0 {
			if id < 0x80 {
				var file = File{};

				file.name = string(make([]u8, id));
				buffer.read(&reader, file.name);

				file.id = next_id;
				next_id++;

				var file_allocation = fat.files[file.id];
				file.size = file_allocation.size;
				file.offset = file_allocation.offset;
				file.data = rom[file.offset..file.offset + file.size];

				append(&main.sub_table.files, file);
			} else if id > 0x80 {
				var folder = Folder{};

				folder.name = string(make([]u8, id - 0x80));
				buffer.read(&reader, folder.name);
				folder.id = buffer.read_u16(&reader);

				append(&main.sub_table.folders, folder);
			}

			id = buffer.read_u8(&reader);
		}

		append(&mains, main);
		reader.offset = current_offset;
	}

	proc build_folder(mains: []MainFNT, id: u16, name: string) -> Folder {
		var main = mains[id & 0xFFF];
		var folder = Folder{};
		folder.name = name;
		folder.id = id;
		folder.files = main.sub_table.files;

		for f in main.sub_table.folders {
			append(&folder.folders, build_folder(mains, f.id, f.name));
		}

		return folder;
	}

	var root = build_folder(mains[..], 0, "root");
	root.id = folder_count;

	return root;
}


proc get_file(folder: Folder, path: string) -> (File, bool) {
	proc index_of(array: []u8, item: u8) -> int {
		for it, index in array {
			if item == it { return index; }
		}

		return -1;
	}

	var index = index_of([]u8(path), 47 /* '/'. #rune don't work? */);
	
	if index >= 0 {
		var folder_name = path[0..index - 1];

		for f in folder.folders {
			if f.name == folder_name { return get_file(f, path[index + 1..len(path)-1]); }
		}

	} else {
		for f in folder.files {
			if f.name == path { return f, true; }
		}
	}

	return File{}, false;
}

type Pokemon struct {
	hp, attack, defense, speed, sp_attack, sp_defense: u8,
	type1, type2: u8,
	catch_rate: u8,
	common_held, rare_held, dark_grass_held: u16,
	exp_curve: u8,
	ability1, ability2, ability3: u8,
}

proc get_pokemons(rom: Rom) -> []Pokemon {
	const bw2_pokemon_stats_path = "a/0/1/6";
	const bw2_first_pokemon_offset = 5732;
	const bw2_pokemon_data_count = 76;

	var pokemons: [dynamic]Pokemon;
	var file, success = get_file(rom.root_folder, bw2_pokemon_stats_path);
	var curr_offset = bw2_first_pokemon_offset;

	for curr_offset < len(file.data) {
		var next_offset = curr_offset + bw2_pokemon_data_count;
		var pokemon_data = file.data[curr_offset .. next_offset];
		curr_offset = next_offset;

		append(&pokemons, 
			Pokemon{
				hp = pokemon_data[0],
				attack = pokemon_data[1],
				defense = pokemon_data[2],
				speed = pokemon_data[3],
				sp_attack = pokemon_data[4],
				sp_defense = pokemon_data[5],
				type1 = pokemon_data[6],
				type2 = pokemon_data[7],
				catch_rate = pokemon_data[8],
				common_held = buffer.read_u16(pokemon_data, 12),
				rare_held = buffer.read_u16(pokemon_data, 14),
				dark_grass_held = buffer.read_u16(pokemon_data, 14),
				exp_curve = pokemon_data[21],
				ability1 = pokemon_data[24],
				ability2 = pokemon_data[25],
				ability3 = pokemon_data[26],
			}
		);
	}

	return pokemons[..];
}