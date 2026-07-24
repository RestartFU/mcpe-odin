package main

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"image/color"

	"github.com/go-gl/mathgl/mgl32"
	"github.com/google/uuid"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
)

func main() {
	var buffer bytes.Buffer
	writer := protocol.NewWriter(&buffer, 0)

	u16, i16 := uint16(0x1234), int16(-1234)
	u32, i32 := uint32(0x12345678), int32(-123456)
	beI32 := int32(0x12345678)
	u64, i64 := uint64(0x0123456789abcdef), int64(-123456789)
	f32, f64 := float32(123.5), float64(-987.25)
	truth, falsity := true, false
	writer.Uint16(&u16)
	writer.Int16(&i16)
	writer.Uint32(&u32)
	writer.Int32(&i32)
	writer.BEInt32(&beI32)
	writer.Uint64(&u64)
	writer.Int64(&i64)
	writer.Float32(&f32)
	writer.Float64(&f64)
	writer.Bool(&truth)
	writer.Bool(&falsity)

	for _, value := range []uint32{0, 1, 127, 128, 255, 300, ^uint32(0)} {
		writer.Varuint32(&value)
	}
	for _, value := range []int32{
		-1 << 31, -1_000_000, -1, 0, 1, 1_000_000, 1<<31 - 1,
	} {
		writer.Varint32(&value)
	}
	for _, value := range []uint64{0, 1, 127, 128, 300, ^uint64(0)} {
		writer.Varuint64(&value)
	}
	for _, value := range []int64{
		-1 << 63, -1_000_000_000_000, -1, 0, 1, 1<<63 - 1,
	} {
		writer.Varint64(&value)
	}

	text, utf := "Minecraft", "Bedrock"
	data := []byte{1, 2, 3, 4}
	writer.String(&text)
	writer.StringUTF(&utf)
	writer.ByteSlice(&data)
	vec2 := mgl32.Vec2{1.25, -2.5}
	vec3 := mgl32.Vec3{1.25, -2.5, 9.75}
	block := protocol.BlockPos{-12, 64, 3456}
	chunk := protocol.ChunkPos{-100, 200}
	subChunk := protocol.SubChunkPos{-2, 10, 44}
	sound := mgl32.Vec3{1.25, -2.5, 9.75}
	rotation := float32(180)
	id := uuid.MustParse("00112233-4455-6677-8899-aabbccddeeff")
	rgba := color.RGBA{R: 1, G: 2, B: 3, A: 4}
	writer.Vec2(&vec2)
	writer.Vec3(&vec3)
	writer.BlockPos(&block)
	writer.ChunkPos(&chunk)
	writer.SubChunkPos(&subChunk)
	writer.SoundPos(&sound)
	writer.ByteFloat(&rotation)
	writer.UUID(&id)
	writer.RGBA(&rgba)
	writer.VarRGBA(&rgba)

	fmt.Printf("protocol_codec %s\n", hex.EncodeToString(buffer.Bytes()))
}
