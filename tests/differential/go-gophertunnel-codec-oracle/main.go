package main

import (
	"bytes"
	"compress/flate"
	"encoding/hex"
	"fmt"
	"image/color"
	"io"

	"github.com/go-gl/mathgl/mgl32"
	"github.com/google/uuid"
	"github.com/sandertv/gophertunnel/minecraft/nbt"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
)

type nestedNBT struct {
	Name string
}

type nbtFixture struct {
	Byte   byte
	Short  int16
	Int    int32
	Long   int64
	Float  float32
	Double float64
	Bytes  [4]byte
	String string
	List   []int32
	Nested nestedNBT
	Ints   [3]int32
	Longs  [2]int64
}

type nbtDumpFixture struct {
	Values []int32
}

type nbtNestedDumpFixture struct {
	Values [][]int32
}

type nbtEmptyStringDumpFixture struct {
	Values []string
}

func emitNBTDump(name string, value any) {
	data, err := nbt.MarshalEncoding(value, nbt.LittleEndian)
	if err != nil {
		panic(err)
	}
	text, err := nbt.Dump(data, nbt.LittleEndian)
	if err != nil {
		panic(err)
	}
	fmt.Printf("%s %s\n", name, hex.EncodeToString([]byte(text)))
}

func encodePacket(pk packet.Packet, sender, target byte) []byte {
	var buffer bytes.Buffer
	header := packet.Header{
		PacketID:        pk.ID(),
		SenderSubClient: sender,
		TargetSubClient: target,
	}
	if err := header.Write(&buffer); err != nil {
		panic(err)
	}
	writer := protocol.NewWriter(&buffer, 0)
	pk.Marshal(writer)
	return buffer.Bytes()
}

func emitPacket(name string, pk packet.Packet, sender, target byte) {
	data := encodePacket(pk, sender, target)
	fmt.Printf("%s %s\n", name, hex.EncodeToString(data))
}

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

	fixture := nbtFixture{
		Byte:   0x7f,
		Short:  -1234,
		Int:    -123456,
		Long:   -1234567890123,
		Float:  123.5,
		Double: -987.25,
		Bytes:  [4]byte{1, 2, 3, 4},
		String: "Minecraft",
		List:   []int32{1, -2, 3},
		Nested: nestedNBT{Name: "inside"},
		Ints:   [3]int32{-1, 0, 1},
		Longs:  [2]int64{-1 << 63, 1<<63 - 1},
	}
	encodings := []struct {
		name     string
		encoding nbt.Encoding
	}{
		{"nbt_network_little", nbt.NetworkLittleEndian},
		{"nbt_little", nbt.LittleEndian},
		{"nbt_network_big", nbt.NetworkBigEndian},
		{"nbt_big", nbt.BigEndian},
	}
	for _, entry := range encodings {
		data, err := nbt.MarshalEncoding(fixture, entry.encoding)
		if err != nil {
			panic(err)
		}
		fmt.Printf("%s %s\n", entry.name, hex.EncodeToString(data))
	}

	emitNBTDump(
		"nbt_dump",
		nbtDumpFixture{Values: []int32{1, -2, 3}},
	)
	emitNBTDump(
		"nbt_dump_nested",
		nbtNestedDumpFixture{Values: [][]int32{{1}}},
	)
	emitNBTDump(
		"nbt_dump_empty_string",
		nbtEmptyStringDumpFixture{Values: []string{}},
	)
	emitNBTDump(
		"nbt_dump_empty_int",
		nbtDumpFixture{Values: []int32{}},
	)

	emitPacket(
		"packet_request_network_settings",
		&packet.RequestNetworkSettings{ClientProtocol: 1001},
		2,
		3,
	)
	emitPacket(
		"packet_network_settings",
		&packet.NetworkSettings{
			CompressionThreshold:    256,
			CompressionAlgorithm:    packet.CompressionAlgorithmSnappy,
			ClientThrottle:          true,
			ClientThrottleThreshold: 12,
			ClientThrottleScalar:    0.75,
		},
		0,
		0,
	)
	emitPacket(
		"packet_disconnect",
		&packet.Disconnect{
			Reason:          57,
			Message:         "Disconnected",
			FilteredMessage: "Filtered",
		},
		0,
		0,
	)
	emitPacket(
		"packet_disconnect_hidden",
		&packet.Disconnect{
			Reason:                  57,
			HideDisconnectionScreen: true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_set_time",
		&packet.SetTime{Time: -12_345},
		0,
		0,
	)
	emitPacket(
		"packet_network_stack_latency",
		&packet.NetworkStackLatency{
			Timestamp:     -1_234_567_890,
			NeedsResponse: true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_set_spawn_position",
		&packet.SetSpawnPosition{
			SpawnType:     packet.SpawnTypeWorld,
			Position:      protocol.BlockPos{-12, 64, 3456},
			Dimension:     2,
			SpawnPosition: protocol.BlockPos{-100, 70, 200},
		},
		0,
		0,
	)
	emitPacket(
		"packet_respawn",
		&packet.Respawn{
			Position:        mgl32.Vec3{1.25, -2.5, 9.75},
			State:           packet.RespawnStateClientReadyToSpawn,
			EntityRuntimeID: 0x1234_5678,
		},
		0,
		0,
	)
	emitPacket(
		"packet_player_hot_bar",
		&packet.PlayerHotBar{
			SelectedHotBarSlot: 7,
			WindowID:           3,
			SelectHotBarSlot:   true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_set_commands_enabled",
		&packet.SetCommandsEnabled{Enabled: true},
		0,
		0,
	)
	emitPacket(
		"packet_set_player_game_type",
		&packet.SetPlayerGameType{GameType: packet.GameTypeSpectator},
		0,
		0,
	)
	emitPacket(
		"packet_simple_event",
		&packet.SimpleEvent{EventType: packet.SimpleEventCommandsDisabled},
		0,
		0,
	)
	emitPacket(
		"packet_spawn_experience_orb",
		&packet.SpawnExperienceOrb{
			Position:         mgl32.Vec3{-1.5, 64.25, 100.75},
			ExperienceAmount: 2477,
		},
		0,
		0,
	)
	emitPacket(
		"packet_show_credits",
		&packet.ShowCredits{
			PlayerRuntimeID: 0x1020_3040,
			StatusType:      packet.ShowCreditsStatusEnd,
		},
		0,
		0,
	)
	emitPacket(
		"packet_transfer",
		&packet.Transfer{
			Address:     "example.org",
			Port:        19132,
			ReloadWorld: true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_stop_sound",
		&packet.StopSound{
			SoundName:       "music.game",
			StopMusicLegacy: true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_set_last_hurt_by",
		&packet.SetLastHurtBy{EntityType: -17},
		0,
		0,
	)
	emitPacket(
		"packet_set_default_game_type",
		&packet.SetDefaultGameType{GameType: packet.GameTypeCreative},
		0,
		0,
	)
	emitPacket(
		"packet_change_dimension",
		&packet.ChangeDimension{
			Dimension:       packet.DimensionNether,
			Position:        mgl32.Vec3{8.5, 72.25, -3.75},
			Respawn:         true,
			LoadingScreenID: protocol.Option(uint32(0x1234_5678)),
		},
		0,
		0,
	)
	emitPacket(
		"packet_change_dimension_without_loading_screen",
		&packet.ChangeDimension{
			Dimension: packet.DimensionEnd,
			Position:  mgl32.Vec3{0, 80, 0},
		},
		0,
		0,
	)
	emitPacket(
		"packet_server_bound_loading_screen",
		&packet.ServerBoundLoadingScreen{
			Type:            packet.LoadingScreenTypeStart,
			LoadingScreenID: protocol.Option(uint32(0x1234_5678)),
		},
		0,
		0,
	)
	emitPacket(
		"packet_server_bound_loading_screen_without_id",
		&packet.ServerBoundLoadingScreen{
			Type: packet.LoadingScreenTypeEnd,
		},
		0,
		0,
	)
	emitPacket(
		"packet_remove_actor",
		&packet.RemoveActor{EntityUniqueID: -0x1020_3040},
		0,
		0,
	)
	emitPacket(
		"packet_take_item_actor",
		&packet.TakeItemActor{
			ItemEntityRuntimeID:  0x1020,
			TakerEntityRuntimeID: 0x3040,
		},
		0,
		0,
	)
	emitPacket(
		"packet_block_pick_request",
		&packet.BlockPickRequest{
			Position:    protocol.BlockPos{-12, 64, 3456},
			AddBlockNBT: true,
			HotBarSlot:  7,
		},
		0,
		0,
	)
	emitPacket(
		"packet_actor_pick_request",
		&packet.ActorPickRequest{
			EntityUniqueID: -0x0102_0304_0506_0708,
			HotBarSlot:     8,
			WithData:       true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_set_actor_motion",
		&packet.SetActorMotion{
			EntityRuntimeID: 0x1020_3040,
			Velocity:        mgl32.Vec3{1.25, -2.5, 9.75},
			Tick:            123_456,
		},
		0,
		0,
	)
	emitPacket(
		"packet_modal_form_request",
		&packet.ModalFormRequest{
			FormID:   42,
			FormData: []byte(`{"type":"modal"}`),
		},
		0,
		0,
	)
	emitPacket(
		"packet_show_profile",
		&packet.ShowProfile{XUID: "2533274790395904"},
		0,
		0,
	)
	emitPacket(
		"packet_remove_objective",
		&packet.RemoveObjective{ObjectiveName: "kills"},
		0,
		0,
	)
	emitPacket(
		"packet_set_local_player_as_initialised",
		&packet.SetLocalPlayerAsInitialised{
			EntityRuntimeID: 0x1234_5678,
		},
		0,
		0,
	)
	emitPacket(
		"packet_update_player_game_type",
		&packet.UpdatePlayerGameType{
			GameType:       packet.GameTypeAdventure,
			PlayerUniqueID: -123_456,
			Tick:           98_765,
		},
		0,
		0,
	)
	emitPacket(
		"packet_filter_text",
		&packet.FilterText{Text: "hello", FromServer: true},
		0,
		0,
	)
	emitPacket(
		"packet_simulation_type",
		&packet.SimulationType{
			SimulationType: packet.SimulationTypeTest,
		},
		0,
		0,
	)
	emitPacket(
		"packet_toast_request",
		&packet.ToastRequest{Title: "Title", Message: "Message"},
		0,
		0,
	)
	emitPacket(
		"packet_award_achievement",
		&packet.AwardAchievement{AchievementID: -1234},
		0,
		0,
	)
	emitPacket(
		"packet_client_bound_close_form",
		&packet.ClientBoundCloseForm{},
		0,
		0,
	)
	emitPacket(
		"packet_login",
		&packet.Login{
			ClientProtocol:    1001,
			ConnectionRequest: []byte{1, 2, 3, 4},
		},
		0,
		0,
	)
	emitPacket(
		"packet_resource_pack_client_response",
		&packet.ResourcePackClientResponse{
			Response: packet.PackResponseSendPacks,
			PacksToDownload: []string{
				"pack-one_1.0.0",
				"pack-two_2.0.0",
			},
		},
		0,
		0,
	)
	emitPacket(
		"packet_resource_pack_data_info",
		&packet.ResourcePackDataInfo{
			UUID:          "d2d3a4b5-c6d7-48e9-a001-020304050607",
			DataChunkSize: 1_048_576,
			ChunkCount:    16,
			Size:          15_500_000,
			Hash:          []byte{0xde, 0xad, 0xbe, 0xef},
			Premium:       true,
			PackType:      packet.ResourcePackTypeResources,
		},
		0,
		0,
	)
	emitPacket(
		"packet_resource_pack_chunk_data",
		&packet.ResourcePackChunkData{
			UUID:        "d2d3a4b5-c6d7-48e9-a001-020304050607",
			ChunkIndex:  7,
			DataOffset:  7 * 1_048_576,
			Data:        []byte{9, 8, 7, 6},
		},
		0,
		0,
	)
	emitPacket(
		"packet_resource_pack_chunk_request",
		&packet.ResourcePackChunkRequest{
			UUID:       "d2d3a4b5-c6d7-48e9-a001-020304050607",
			ChunkIndex: -1,
		},
		0,
		0,
	)

	var batch bytes.Buffer
	batchEncoder := packet.NewEncoder(&batch)
	if err := batchEncoder.Encode([][]byte{
		encodePacket(&packet.SetTime{Time: 42}, 0, 0),
		encodePacket(
			&packet.RequestNetworkSettings{ClientProtocol: 1001},
			0,
			0,
		),
	}); err != nil {
		panic(err)
	}
	fmt.Printf("packet_batch %s\n", hex.EncodeToString(batch.Bytes()))

	goFlateInput := bytes.Repeat(
		[]byte("Minecraft Bedrock packet compression "),
		64,
	)
	fmt.Printf(
		"flate_go_to_odin %s\n",
		hex.EncodeToString(goFlateInput),
	)

	odinFlate := []byte{
		0x01, 0x10, 0x00, 0xef, 0xff,
		0x4f, 0x64, 0x69, 0x6e, 0x20, 0x72, 0x61,
		0x77, 0x20, 0x44, 0x45, 0x46, 0x4c, 0x41, 0x54,
		0x45,
	}
	flateReader := flate.NewReader(bytes.NewReader(odinFlate))
	odinDecoded, err := io.ReadAll(flateReader)
	if err != nil {
		panic(err)
	}
	if err := flateReader.Close(); err != nil {
		panic(err)
	}
	fmt.Printf(
		"flate_odin_to_go %s\n",
		hex.EncodeToString(odinDecoded),
	)
}
