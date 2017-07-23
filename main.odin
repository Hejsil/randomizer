
import "os.odin";
import "fmt.odin";
import "mem.odin";
import "math.odin";
import "buffer.odin";
import "crc.odin";
import "sys/windows.odin";

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

proc load_rom_header(rom: []u8) -> Header {
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

type Banner struct {
	version, crc16: u16,
	check_crc: bool,
	reserved: [28]u8,
	tile_data: [512]u8,
	palette: [32]u8,
	japanese_title, english_title, french_title: [256]u8, 
	german_title, italian_title, spanish_title: [256]u8,
}

proc load_rom_banner(rom: []u8, offset: u32) -> Banner {
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


type File_Allocation struct {
	size, offset: u32
}

type FAT struct {
	files: []File_Allocation
}

proc deinit(fat: FAT) {
	free(fat.files);
}

proc load_fat(rom: []u8, offset, size: u32) -> FAT {
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

type File struct {
	offset, size: u32,
	name: []u8, // NOTE: Heap!
	id: u16,
	// path: []u8, // NOTE: Heap!
	//tag: any
}

type Folder struct {
	files: [dynamic]File, // NOTE: Heap!
	folders: [dynamic]Folder, // NOTE: Heap!
	name: []u8, // NOTE: Heap!
	id: u16,
	//tag: any
}

type MainFNT struct {
	offset: u32,
	first_file_id: u16,
	parent_id: u16,
	sub_table: Folder
}

proc load_files(rom: []u8, fnt_offset: u32, fat: FAT) -> Folder {
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

				file.name = make([]u8, id);
				buffer.read(&reader, file.name);

				file.id = next_id;
				next_id++;

				var file_allocation = fat.files[file.id];
				file.size = file_allocation.size;
				file.offset = file_allocation.offset;
				// file.path = 

				append(&main.sub_table.files, file);
			} else if id > 0x80 {
				var folder = Folder{};

				folder.name = make([]u8, id - 0x80);
				buffer.read(&reader, folder.name);
				folder.id = buffer.read_u16(&reader);

				append(&main.sub_table.folders, folder);
			}

			id = buffer.read_u8(&reader);
		}

		append(&mains, main);
		reader.offset = current_offset;
	}

	proc build_folder(mains: []MainFNT, id: u16, name: []u8) -> Folder {
		fmt.println(id);
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

	var root = build_folder(mains[..], 0, []u8{});
	root.id = folder_count;

	return root;
}


proc print_data_as_str(arr: []u8) {
	for c in arr { fmt.print(rune(c)); }
}

proc print_indent(i: int) {
	for p in 0..<i*2 {
		fmt.print(" ");
	}
}

proc print_folder(folder: Folder, i: int = 0) {
	print_indent(i); fmt.println("{");
	i++;
	print_indent(i); fmt.println("id = ", folder.id);
	print_indent(i); fmt.print("name = \""); print_data_as_str(folder.name); fmt.println("\"");

	print_indent(i); fmt.println("files = [");
	i++;

	for f in folder.files {
		print_indent(i); fmt.println("{");
		i++;

		print_indent(i); fmt.println("id = ", f.id);
		print_indent(i); fmt.println("size = ", f.size);
		print_indent(i); fmt.println("offset = ", f.offset);
		print_indent(i); fmt.print("name = \""); print_data_as_str(f.name); fmt.println("\"");

		i--;
		print_indent(i); fmt.println("}");
	}

	i--;
	print_indent(i); fmt.println("]");


	
	print_indent(i); fmt.println("folders = [");
	i++;

	for f in folder.folders {
		print_folder(f, i);
	}

	i--;
	print_indent(i); fmt.println("]");

	i--;
	print_indent(i); fmt.println("}");
}

proc main() {
	var rom, success = os.read_entire_file("D:\\Mega\\ProgramDataDump\\RandomizerSettings\\PokemonBlack2.nds");
	defer free(rom);

	if success {
		var header = load_rom_header(rom);
		var banner = load_rom_banner(rom, header.banner_offset);
		var fat = load_fat(rom, header.fat_offset, header.fat_size);
		var folder = load_files(rom, header.fnt_offset, fat);
		print_folder(folder);
		//fmt.println(header);
		//fmt.println(banner);
	}
}