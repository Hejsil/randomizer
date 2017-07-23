type Buffer_Reader struct {
	data: []u8,
	offset : u64
}

proc read(r: ^Buffer_Reader, dst: []u8) {
	copy(dst, r.data[r.offset .. r.offset + u64(len(dst))]); 
	r.offset += u64(len(dst));
}

proc read_u8(r: ^Buffer_Reader) -> u8 {
	var result = r.data[r.offset];
	r.offset += size_of(u8);

	return result;
}

proc read_u16(r: ^Buffer_Reader) -> u16 {
	var result = (^u16(&r.data[r.offset]))^;
	r.offset += size_of(u16);

	return result;
}

proc read_u32(r: ^Buffer_Reader) -> u32 {
	var result = (^u32(&r.data[r.offset]))^;
	r.offset += size_of(u32);

	return result;
}

proc read_u64(r: ^Buffer_Reader) -> u64 {
	var result = (^u64(&r.data[r.offset]))^;
	r.offset += size_of(u64);

	return result;
}