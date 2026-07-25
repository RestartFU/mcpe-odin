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
	login "github.com/sandertv/gophertunnel/minecraft/protocol/login"
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

func emitIdentityValidation(name string, data login.IdentityData) {
	valid := byte(0)
	if data.Validate() == nil {
		valid = 1
	}
	fmt.Printf("%s %02x\n", name, valid)
}

func emitDeviceIDFormat(name, value string) {
	fmt.Printf("%s %02x\n", name, byte(login.DeviceID(value).Format()))
}

func main() {
	identity := login.IdentityData{
		XUID:        "2533274790395904",
		Identity:    "00112233-4455-6677-8899-aabbccddeeff",
		DisplayName: "Steve",
	}
	emitIdentityValidation("login_identity_valid", identity)
	identity.DisplayName = "A#"
	emitIdentityValidation("login_identity_online_regex_quirk", identity)
	identity.XUID = ""
	identity.DisplayName = "É#"
	emitIdentityValidation("login_identity_offline_unicode", identity)
	identity.DisplayName = "###"
	emitIdentityValidation("login_identity_invalid_name", identity)
	identity.DisplayName = "Steve"
	identity.Identity = "00000000-0000-0000-0000-000000000000"
	emitIdentityValidation("login_identity_nil_uuid", identity)
	identity.Identity = "00112233-4455-6677-8899-aabbccddeeff"
	identity.XUID = "not-a-number"
	emitIdentityValidation("login_identity_invalid_xuid", identity)
	identity.XUID = "2533274790395904"
	identity.Identity = "00112233445566778899aabbccddeeff"
	emitIdentityValidation("login_identity_raw_uuid", identity)
	identity.Identity = "URN:UUID:00112233-4455-6677-8899-aabbccddeeff"
	emitIdentityValidation("login_identity_urn_uuid", identity)
	identity.Identity = "!00112233-4455-6677-8899-aabbccddeeff?"
	emitIdentityValidation("login_identity_wrapped_uuid", identity)
	identity.Identity = "00112233-4455-6677-8899-aabbccddeeff"
	identity.DisplayName = "Steve Alex"
	emitIdentityValidation("login_identity_single_space", identity)
	identity.DisplayName = "Steve"
	identity.XUID = "1_2"
	emitIdentityValidation("login_identity_xuid_underscore", identity)
	identity.XUID = "+1"
	emitIdentityValidation("login_identity_xuid_plus", identity)
	emitDeviceIDFormat("login_device_id_lower_hex", "ada3dfa4622f4e2fb2c14a496d52db96")
	emitDeviceIDFormat("login_device_id_mixed_hex", "Ada3DFA4622F4E2FB2C14A496D52DB96")
	emitDeviceIDFormat("login_device_id_uuid", "00112233-4455-6677-8899-aabbccddeeff")
	emitDeviceIDFormat("login_device_id_base64", "VlhnpI7TuWyfHiUx3WYwFvQQHbDkv505h6VVo40Cngw=")
	emitDeviceIDFormat("login_device_id_unpadded_base64", "VlhnpI7TuWyfHiUx3WYwFvQQHbDkv505h6VVo40Cngw")
	emitDeviceIDFormat("login_device_id_invalid", "not-a-device-id")

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
			UUID:       "d2d3a4b5-c6d7-48e9-a001-020304050607",
			ChunkIndex: 7,
			DataOffset: 7 * 1_048_576,
			Data:       []byte{9, 8, 7, 6},
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
	packUUID := uuid.MustParse("00112233-4455-6677-8899-aabbccddeeff")
	emitPacket(
		"packet_resource_packs_info",
		&packet.ResourcePacksInfo{
			TexturePackRequired:        true,
			HasAddons:                  true,
			HasScripts:                 true,
			ForceDisableVibrantVisuals: true,
			WorldTemplateUUID:          packUUID,
			WorldTemplateVersion:       "1.0.0",
			TexturePacks: []protocol.TexturePackInfo{
				{
					UUID:            packUUID,
					Version:         "2.0.0",
					Size:            15_500_000,
					ContentKey:      "content-key",
					SubPackName:     "sub-pack",
					ContentIdentity: "identity",
					HasScripts:      true,
					AddonPack:       true,
					RTXEnabled:      true,
					DownloadURL:     "https://example.org/pack.zip",
				},
			},
		},
		0,
		0,
	)
	emitPacket(
		"packet_resource_pack_stack",
		&packet.ResourcePackStack{
			TexturePackRequired: true,
			TexturePacks: []protocol.StackResourcePack{
				{
					UUID:        "00112233-4455-6677-8899-aabbccddeeff",
					Version:     "2.0.0",
					SubPackName: "sub-pack",
				},
			},
			BaseGameVersion: "1.26.30",
			Experiments: []protocol.ExperimentData{
				{Name: "experiment", Enabled: true},
			},
			ExperimentsPreviouslyToggled: true,
			IncludeEditorPacks:           true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_text_raw",
		&packet.Text{
			TextType: packet.TextTypeRaw,
			Message:  "raw message",
		},
		0,
		0,
	)
	emitPacket(
		"packet_text_chat",
		&packet.Text{
			TextType:        packet.TextTypeChat,
			SourceName:      "Steve",
			Message:         "hello",
			XUID:            "2533274790395904",
			PlatformChatID:  "platform",
			FilteredMessage: protocol.Option("filtered hello"),
		},
		0,
		0,
	)
	emitPacket(
		"packet_text_translation",
		&packet.Text{
			TextType:         packet.TextTypeTranslation,
			NeedsTranslation: true,
			Message:          "chat.type.text",
			Parameters:       []string{"Steve", "hello"},
		},
		0,
		0,
	)
	emitPacket(
		"packet_set_title",
		&packet.SetTitle{
			ActionType:       packet.TitleActionSetTitle,
			Text:             "Welcome",
			FadeInDuration:   10,
			RemainDuration:   70,
			FadeOutDuration:  20,
			XUID:             "2533274790395904",
			PlatformOnlineID: "1234",
			FilteredMessage:  "Filtered Welcome",
		},
		0,
		0,
	)
	emitPacket(
		"packet_show_store_offer",
		&packet.ShowStoreOffer{
			OfferID: packUUID,
			Type:    packet.StoreOfferTypeDressingRoom,
		},
		0,
		0,
	)
	emitPacket(
		"packet_purchase_receipt",
		&packet.PurchaseReceipt{
			Receipts: []string{"receipt-one", "receipt-two"},
		},
		0,
		0,
	)
	emitPacket(
		"packet_modal_form_response",
		&packet.ModalFormResponse{
			FormID:       42,
			ResponseData: protocol.Option([]byte{1, 2, 3}),
			CancelReason: protocol.Option(
				uint8(packet.ModalFormCancelReasonUserBusy),
			),
		},
		0,
		0,
	)
	emitPacket(
		"packet_server_settings_request",
		&packet.ServerSettingsRequest{},
		0,
		0,
	)
	emitPacket(
		"packet_server_settings_response",
		&packet.ServerSettingsResponse{
			FormID:   43,
			FormData: []byte{4, 5, 6},
		},
		0,
		0,
	)
	emitPacket(
		"packet_settings_command",
		&packet.SettingsCommand{
			CommandLine:    "gamerule showcoordinates true",
			SuppressOutput: true,
		},
		0,
		0,
	)
	emitPacket("packet_ui_reload", &packet.ClientBoundDataDrivenUIReload{}, 0, 0)
	emitPacket("packet_refresh_entitlements", &packet.RefreshEntitlements{}, 0, 0)
	emitPacket("packet_packs_ready_validation", &packet.ResourcePacksReadyForValidation{}, 0, 0)
	emitPacket("packet_ticking_areas", &packet.TickingAreasLoadStatus{Preload: true}, 0, 0)
	emitPacket("packet_behaviour_tree", &packet.AddBehaviourTree{BehaviourTree: "tree"}, 0, 0)
	emitPacket(
		"packet_item_cooldown",
		&packet.ClientStartItemCooldown{Category: "ender_pearl", Duration: -20},
		0,
		0,
	)
	emitPacket(
		"packet_remove_volume",
		&packet.RemoveVolumeEntity{EntityRuntimeID: 12345, Dimension: -1},
		0,
		0,
	)
	emitPacket(
		"packet_screen_animation",
		&packet.OnScreenTextureAnimation{AnimationType: 0x12345678},
		0,
		0,
	)
	emitPacket(
		"packet_automation_connect",
		&packet.AutomationClientConnect{ServerURI: "localhost:8000/ws"},
		0,
		0,
	)
	emitPacket("packet_photo_info", &packet.PhotoInfoRequest{PhotoID: -123456789}, 0, 0)
	emitPacket(
		"packet_map_locked_copy",
		&packet.MapCreateLockedCopy{OriginalMapID: -7, NewMapID: 9001},
		0,
		0,
	)
	emitPacket(
		"packet_script_message",
		&packet.ScriptMessage{Identifier: "mcpe:test", Data: []byte{0, 1, 2, 255}},
		0,
		0,
	)
	emitPacket(
		"packet_open_sign",
		&packet.OpenSign{Position: protocol.BlockPos{-12, 64, 3456}, FrontSide: true},
		0,
		0,
	)
	emitPacket(
		"packet_ui_close_screen",
		&packet.ClientBoundDataDrivenUICloseScreen{FormID: protocol.Option(uint32(42))},
		0,
		0,
	)
	emitPacket(
		"packet_actor_identifiers",
		&packet.AvailableActorIdentifiers{SerialisedEntityIdentifiers: []byte{10, 0, 0}},
		0,
		0,
	)
	emitPacket(
		"packet_current_structure",
		&packet.CurrentStructureFeature{CurrentFeature: "minecraft:village"},
		0,
		0,
	)
	emitPacket(
		"packet_server_stats",
		&packet.ServerStats{ServerTime: 12.5, NetworkTime: 3.25},
		0,
		0,
	)
	emitPacket(
		"packet_anvil_damage",
		&packet.AnvilDamage{Damage: 2, AnvilPosition: protocol.BlockPos{-12, 64, 3456}},
		0,
		0,
	)
	emitPacket(
		"packet_debug_info",
		&packet.DebugInfo{PlayerUniqueID: -99, Data: []byte{4, 5, 6}},
		0,
		0,
	)
	emitPacket(
		"packet_create_photo",
		&packet.CreatePhoto{EntityUniqueID: -7, PhotoName: "photo", ItemName: "portfolio"},
		0,
		0,
	)
	emitPacket(
		"packet_code_builder",
		&packet.CodeBuilder{URL: "ws://localhost:8080", ShouldOpenCodeBuilder: true},
		0,
		0,
	)
	emitPacket(
		"packet_education_resource",
		&packet.EducationResourceURI{
			Resource: protocol.EducationSharedResourceURI{
				ButtonName: "Learn",
				LinkURI:    "https://example.org/lesson",
			},
		},
		0,
		0,
	)
	emitPacket(
		"packet_player_fog",
		&packet.PlayerFog{Stack: []string{"minecraft:fog_ocean", "custom:fog"}},
		0,
		0,
	)
	emitPacket(
		"packet_death_info",
		&packet.DeathInfo{Cause: "suffocation", Messages: []string{"one", "two"}},
		0,
		0,
	)
	emitPacket("packet_client_cache_status", &packet.ClientCacheStatus{Enabled: true}, 0, 0)
	emitPacket(
		"packet_level_event_generic",
		&packet.LevelEventGeneric{EventID: 2026, SerialisedEventData: []byte{1, 2, 3}},
		0,
		0,
	)
	emitPacket(
		"packet_container_close",
		&packet.ContainerClose{WindowID: 4, ContainerType: 12, ServerSide: true},
		0,
		0,
	)
	emitPacket(
		"packet_container_set_data",
		&packet.ContainerSetData{WindowID: 5, Key: -2, Value: 300},
		0,
		0,
	)
	emitPacket(
		"packet_gui_pick_item",
		&packet.GUIDataPickItem{ItemName: "Sword", ItemEffects: "+7 Attack", HotBarSlot: -1},
		0,
		0,
	)
	emitPacket(
		"packet_completed_item",
		&packet.CompletedUsingItem{UsedItemID: -1234, UseMethod: packet.UseItemEat},
		0,
		0,
	)
	emitPacket(
		"packet_agent_animation",
		&packet.AgentAnimation{Animation: 7, EntityRuntimeID: 1<<40 + 9},
		0,
		0,
	)
	emitPacket(
		"packet_camera",
		&packet.Camera{CameraEntityUniqueID: -7, TargetPlayerUniqueID: 9001},
		0,
		0,
	)
	emitPacket(
		"packet_update_sound_data",
		&packet.ClientboundUpdateSoundData{
			ServerSoundHandle: 0x0123456789abcdef,
			SoundEvent:        packet.SoundDataEventStop,
		},
		0,
		0,
	)
	emitPacket(
		"packet_game_test_results",
		&packet.GameTestResults{Name: "test:name", Succeeded: false, Error: "failed"},
		0,
		0,
	)
	emitPacket(
		"packet_hurt_armour",
		&packet.HurtArmour{Cause: -2, Damage: 7, ArmourSlots: 0x11},
		0,
		0,
	)
	emitPacket(
		"packet_lesson_progress",
		&packet.LessonProgress{Identifier: "lesson.one", Action: packet.LessonActionComplete, Score: 99},
		0,
		0,
	)
	emitPacket(
		"packet_motion_hints",
		&packet.MotionPredictionHints{
			EntityRuntimeID: 1<<40 + 10,
			Velocity:        mgl32.Vec3{1.25, -2.5, 3.75},
			OnGround:        true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_multiplayer_settings",
		&packet.MultiPlayerSettings{ActionType: packet.RefreshJoinCode},
		0,
		0,
	)
	emitPacket(
		"packet_violation_warning",
		&packet.PacketViolationWarning{
			Type:             packet.ViolationTypeMalformed,
			Severity:         packet.ViolationSeverityFinalWarning,
			PacketID:         42,
			ViolationContext: "bad payload",
		},
		0,
		0,
	)
	emitPacket(
		"packet_request_permissions",
		&packet.RequestPermissions{
			EntityUniqueID:       -9001,
			PermissionLevel:      2,
			RequestedPermissions: 0x1234,
		},
		0,
		0,
	)
	emitPacket(
		"packet_update_adventure",
		&packet.UpdateAdventureSettings{
			NoPvM: true, NoMvP: false, ImmutableWorld: true,
			ShowNameTags: false, AutoJump: true,
		},
		0,
		0,
	)
	emitPacket(
		"packet_input_locks",
		&packet.UpdateClientInputLocks{
			Locks: packet.ClientInputLockCamera | packet.ClientInputLockJump,
		},
		0,
		0,
	)
	emitPacket(
		"packet_client_options",
		&packet.UpdateClientOptions{
			GraphicsMode:    protocol.Option(byte(packet.GraphicsModeAdvanced)),
			FilterProfanity: protocol.Option(true),
		},
		0,
		0,
	)
	emitPacket(
		"packet_actor_event",
		&packet.ActorEvent{
			EntityRuntimeID: 1<<40 + 11, EventType: packet.ActorEventHurt,
			EventData: -3, FireAtPosition: protocol.Option(mgl32.Vec3{1, 2, 3}),
		},
		0, 0,
	)
	emitPacket(
		"packet_agent_action",
		&packet.AgentAction{Identifier: "action-id", Action: 4, Response: []byte{1, 2, 3}},
		0, 0,
	)
	emitPacket(
		"packet_block_event",
		&packet.BlockEvent{
			Position:  protocol.BlockPos{-12, 64, 3456},
			EventType: packet.BlockEventChangeChestState, EventData: 1,
		},
		0, 0,
	)
	emitPacket(
		"packet_camera_shake",
		&packet.CameraShake{Intensity: 2.5, Duration: 4.25, Type: 1, Action: 0},
		0, 0,
	)
	emitPacket(
		"packet_code_builder_source",
		&packet.CodeBuilderSource{Operation: 2, Category: 1, CodeStatus: 5},
		0, 0,
	)
	emitPacket(
		"packet_emote",
		&packet.Emote{
			EntityRuntimeID: 1<<40 + 12, EmoteLength: 80,
			EmoteID: "emote-id", XUID: "1234", PlatformID: "platform", Flags: 3,
		},
		0, 0,
	)
	emitPacket(
		"packet_game_test_request",
		&packet.GameTestRequest{
			Name: "test:name", Rotation: 2, Repetitions: 3,
			Position: protocol.BlockPos{-12, 64, 3456}, StopOnError: true,
			TestsPerRow: 4, MaxTestsPerBatch: 5,
		},
		0, 0,
	)
	emitPacket(
		"packet_lab_table",
		&packet.LabTable{
			ActionType: 1, Position: protocol.BlockPos{-12, 64, 3456},
			ReactionType: 7,
		},
		0, 0,
	)
	emitPacket(
		"packet_lectern_update",
		&packet.LecternUpdate{Page: 2, PageCount: 10, Position: protocol.BlockPos{-12, 64, 3456}},
		0, 0,
	)
	emitPacket(
		"packet_npc_request",
		&packet.NPCRequest{
			EntityRuntimeID: 1<<40 + 13, RequestType: 1,
			CommandString: "/say hello", ActionType: 2, SceneName: "scene",
		},
		0, 0,
	)
	emitPacket(
		"packet_player_action",
		&packet.PlayerAction{
			EntityRuntimeID: 1<<40 + 14, ActionType: -2,
			BlockPosition:  protocol.BlockPos{-12, 64, 3456},
			ResultPosition: protocol.BlockPos{-11, 65, 3457}, BlockFace: 3,
		},
		0, 0,
	)
	emitPacket(
		"packet_spawn_particle",
		&packet.SpawnParticleEffect{
			Dimension: 2, EntityUniqueID: -1, Position: mgl32.Vec3{1.25, 2.5, 3.75},
			ParticleName:    "minecraft:test",
			MoLangVariables: protocol.Option([]byte(`{"x":1}`)),
		},
		0, 0,
	)
	emitPacket(
		"packet_cache_blob_status",
		&packet.ClientCacheBlobStatus{
			MissHashes: []uint64{1, 0x0123456789abcdef},
			HitHashes:  []uint64{2, 3},
		},
		0, 0,
	)
	emitPacket(
		"packet_data_ui_show",
		&packet.ClientBoundDataDrivenUIShowScreen{
			ScreenID: "screen:test", FormID: 42,
			DataInstanceID: protocol.Option(uint32(99)),
		},
		0, 0,
	)
	emitPacket(
		"packet_sub_client_login",
		&packet.SubClientLogin{ConnectionRequest: []byte{1, 2, 3, 4}},
		0, 0,
	)
	emitPacket(
		"packet_script_custom_event",
		&packet.ScriptCustomEvent{EventName: "test:event", EventData: []byte{4, 5, 6}},
		0, 0,
	)
	emitPacket(
		"packet_emote_list",
		&packet.EmoteList{PlayerRuntimeID: 1<<40 + 15, EmotePieces: []uuid.UUID{packUUID}},
		0, 0,
	)
	emitPacket(
		"packet_party_cookie",
		&packet.SendPartyDestinationCookie{
			Cookie: "opaque", Intent: packet.PartyDestinationCookieIntentOptIn,
			DestinationName: "server",
		},
		0, 0,
	)
	emitPacket(
		"packet_toggle_crafter",
		&packet.PlayerToggleCrafterSlotRequest{
			PosX: -12, PosY: 64, PosZ: 3456, Slot: 8, Disabled: true,
		},
		0, 0,
	)
	emitPacket(
		"packet_client_aim_assist",
		&packet.ClientCameraAimAssist{PresetID: "preset", Action: 1, AllowAimAssist: true},
		0, 0,
	)
	emitPacket(
		"packet_data_screen_closed",
		&packet.ServerBoundDataDrivenScreenClosed{
			FormID: 42, CloseReason: packet.DataDrivenScreenCloseReasonUserBusy,
		},
		0, 0,
	)
	emitPacket(
		"packet_position_tracking_request",
		&packet.PositionTrackingDBClientRequest{RequestAction: 0, TrackingID: -99},
		0, 0,
	)
	emitPacket(
		"packet_party_changed",
		&packet.PartyChanged{
			PartyInfo: protocol.Option(packet.PartyInfo{PartyID: "party", PartyLeader: true}),
		},
		0, 0,
	)
	emitPacket(
		"packet_party_cookie_response",
		&packet.PartyDestinationCookieResponse{Cookie: "opaque", Accepted: true},
		0, 0,
	)
	emitPacket(
		"packet_control_scheme_set",
		&packet.ClientBoundControlSchemeSet{
			ControlScheme: packet.ControlSchemeCameraRelativeStrafe,
		},
		0, 0,
	)
	emitPacket(
		"packet_movement_effect",
		&packet.MovementEffect{
			EntityRuntimeID: 1<<40 + 16,
			Type:            packet.MovementEffectTypeDolphinBoost,
			Duration:        40,
			Tick:            123456,
		},
		0, 0,
	)
	emitPacket(
		"packet_player_video_capture",
		&packet.PlayerVideoCapture{
			Action: packet.PlayerVideoCaptureActionStart, FrameRate: 60,
			FilePrefix: "capture-",
		},
		0, 0,
	)
	emitPacket(
		"packet_player_location",
		&packet.PlayerLocation{
			Type: packet.PlayerLocationTypeCoordinates, EntityUniqueID: -99,
			Position: mgl32.Vec3{1.25, 2.5, 3.75},
		},
		0, 0,
	)
	emitPacket(
		"packet_texture_shift",
		&packet.ClientBoundTextureShift{
			ActionID: packet.TextureShiftActionSync, CollectionName: "collection",
			FromStep: "one", ToStep: "two", AllSteps: []string{"one", "two"},
			CurrentLengthTicks: 10, TotalLengthTicks: 20, Enabled: true,
		},
		0, 0,
	)
	emitPacket(
		"packet_set_hud",
		&packet.SetHud{
			Elements:   []int32{packet.HudElementCrosshair, packet.HudElementHotBar},
			Visibility: packet.HudVisibilityHide,
		},
		0, 0,
	)
	emitPacket(
		"packet_inventory_options",
		&packet.SetPlayerInventoryOptions{
			LeftInventoryTab:  packet.InventoryLeftTabSearch,
			RightInventoryTab: packet.InventoryRightTabCrafting,
			Filtering:         true, InventoryLayout: packet.InventoryLayoutDefault,
			CraftingLayout: packet.InventoryLayoutRecipeBookOnly,
		},
		0, 0,
	)
	emitPacket(
		"packet_entity_overrides",
		&packet.PlayerUpdateEntityOverrides{
			EntityUniqueID: -99, PropertyIndex: 7,
			Type: packet.PlayerUpdateEntityOverridesTypeFloat, FloatValue: 2.5,
		},
		0, 0,
	)
	emitPacket(
		"packet_camera_aim_assist",
		&packet.CameraAimAssist{
			Preset: "preset", Angle: mgl32.Vec2{12.5, 8.25}, Distance: 32,
			TargetMode: 1, Action: packet.CameraAimAssistActionSet,
			ShowDebugRender: true,
		},
		0, 0,
	)
	emitPacket(
		"packet_change_mob_property",
		&packet.ChangeMobProperty{
			EntityUniqueID: -99, Property: "minecraft:test",
			BoolValue: true, StringValue: "value", IntValue: -7, FloatValue: 2.5,
		},
		0, 0,
	)
	emitPacket(
		"packet_mob_effect",
		&packet.MobEffect{
			EntityRuntimeID: 1<<40 + 17, Operation: packet.MobEffectAdd,
			EffectType: packet.EffectSpeed, Amplifier: 2, Particles: true,
			Duration: 600, Tick: 123456, Ambient: false,
		},
		0, 0,
	)
	emitPacket(
		"packet_play_sound",
		&packet.PlaySound{
			SoundName: "note.pling", Position: mgl32.Vec3{1.25, 2.5, -3.75},
			Volume: 0.75, Pitch: 1.25, Handle: protocol.Option(uint64(42)),
		},
		0, 0,
	)
	emitPacket(
		"packet_interact",
		&packet.Interact{
			ActionType:            packet.InteractActionMouseOverEntity,
			TargetEntityRuntimeID: 1<<40 + 18,
			Position:              protocol.Option(mgl32.Vec3{1.25, 2.5, 3.75}),
		},
		0, 0,
	)
	emitPacket(
		"packet_move_actor_absolute",
		&packet.MoveActorAbsolute{
			EntityRuntimeID: 1<<40 + 19, Flags: packet.MoveFlagOnGround,
			Position: mgl32.Vec3{1.25, 2.5, 3.75},
			Rotation: mgl32.Vec3{45, 90, 180},
		},
		0, 0,
	)
	emitPacket(
		"packet_move_actor_delta",
		&packet.MoveActorDelta{
			EntityRuntimeID: 1<<40 + 20,
			Flags: packet.MoveActorDeltaFlagHasX | packet.MoveActorDeltaFlagHasZ |
				packet.MoveActorDeltaFlagHasRotY,
			Position: mgl32.Vec3{1.25, 0, 3.75},
			Rotation: mgl32.Vec3{0, 90, 0},
		},
		0, 0,
	)
	emitPacket(
		"packet_container_open",
		&packet.ContainerOpen{
			WindowID: 4, ContainerType: 12,
			ContainerPosition:       protocol.BlockPos{-12, 64, 3456},
			ContainerEntityUniqueID: -99,
		},
		0, 0,
	)
	emitPacket(
		"packet_chunk_publisher",
		&packet.NetworkChunkPublisherUpdate{
			Position: protocol.BlockPos{-12, 64, 3456}, Radius: 128,
			SavedChunks: []protocol.ChunkPos{{-2, 3}, {4, -5}},
		},
		0, 0,
	)
	emitPacket(
		"packet_add_painting",
		&packet.AddPainting{
			EntityUniqueID: -99, EntityRuntimeID: 1<<40 + 21,
			Position:  mgl32.Vec3{1.25, 2.5, 3.75},
			Direction: 2, Title: "Kebab",
		},
		0, 0,
	)
	emitPacket(
		"packet_animate",
		&packet.Animate{
			ActionType:      packet.AnimateActionSwingArm,
			EntityRuntimeID: 1<<40 + 22, Data: 1.25,
			SwingSource: packet.AnimateSwingSourceAttack,
		},
		0, 0,
	)
	emitPacket(
		"packet_set_actor_link",
		&packet.SetActorLink{
			EntityLink: protocol.EntityLink{
				RiddenEntityUniqueID: -7, RiderEntityUniqueID: -99,
				Type: protocol.EntityLinkRider, Immediate: true,
				RiderInitiated: true, VehicleAngularVelocity: 1.5,
			},
		},
		0, 0,
	)
	emitPacket(
		"packet_map_info_request",
		&packet.MapInfoRequest{
			MapID: -99,
			ClientPixels: []protocol.PixelRequest{{
				Colour: color.RGBA{R: 1, G: 2, B: 3, A: 4}, Index: 300,
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_player_armour_damage",
		&packet.PlayerArmourDamage{
			List: []protocol.PlayerArmourDamageEntry{
				{ArmourSlot: 0, Damage: 7},
				{ArmourSlot: 3, Damage: -2},
			},
		},
		0, 0,
	)
	emitPacket(
		"packet_level_event",
		&packet.LevelEvent{
			EventType: packet.LevelEventParticlesDestroyBlock,
			Position:  mgl32.Vec3{1.25, 2.5, 3.75}, EventData: -7,
		},
		0, 0,
	)
	emitPacket(
		"packet_photo_transfer",
		&packet.PhotoTransfer{
			PhotoName: "photo.png", PhotoData: []byte{1, 2, 3, 4},
			BookID: "book", PhotoType: packet.PhotoTypePhotoItem,
			SourceType: packet.PhotoTypePortfolio, OwnerEntityUniqueID: -99,
			NewPhotoName: "renamed.png",
		},
		0, 0,
	)
	emitPacket(
		"packet_display_objective",
		&packet.SetDisplayObjective{
			DisplaySlot:   packet.ScoreboardSlotSidebar,
			ObjectiveName: "kills", DisplayName: "Kills",
			CriteriaName: "dummy", SortOrder: packet.ScoreboardSortOrderDescending,
		},
		0, 0,
	)
	emitPacket(
		"packet_level_sound_event",
		&packet.LevelSoundEvent{
			SoundType: packet.SoundEventStep,
			Position:  mgl32.Vec3{1.25, 2.5, 3.75}, ExtraData: -7,
			EntityType: "minecraft:zombie", BabyMob: true,
			DisableRelativeVolume: false, EntityUniqueID: -99,
			FireAtPosition: protocol.Option(mgl32.Vec3{4, 5, 6}),
		},
		0, 0,
	)
	emitPacket(
		"packet_animate_entity",
		&packet.AnimateEntity{
			Animation: "animation.test", NextState: "default",
			StopCondition: "query.is_on_ground", StopConditionVersion: 1,
			Controller: "controller.animation.test", BlendOutTime: 0.25,
			EntityRuntimeIDs: []uint64{1<<40 + 23, 1<<40 + 24},
		},
		0, 0,
	)
	emitPacket(
		"packet_set_score_modify",
		&packet.SetScore{
			ActionType: packet.ScoreboardActionModify,
			Entries: []protocol.ScoreboardEntry{{
				EntryID: 7, ObjectiveName: "kills", Score: 42,
				IdentityType: protocol.ScoreboardIdentityFakePlayer,
				DisplayName:  "Player",
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_set_score_remove",
		&packet.SetScore{
			ActionType: packet.ScoreboardActionRemove,
			Entries: []protocol.ScoreboardEntry{{
				EntryID: 7, ObjectiveName: "kills", Score: 42,
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_scoreboard_identity_register",
		&packet.SetScoreboardIdentity{
			ActionType: packet.ScoreboardIdentityActionRegister,
			Entries: []protocol.ScoreboardIdentityEntry{{
				EntryID: 7, EntityUniqueID: -99,
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_scoreboard_identity_clear",
		&packet.SetScoreboardIdentity{
			ActionType: packet.ScoreboardIdentityActionClear,
			Entries:    []protocol.ScoreboardIdentityEntry{{EntryID: 7}},
		},
		0, 0,
	)
	emitPacket(
		"packet_update_block",
		&packet.UpdateBlock{
			Position: protocol.BlockPos{-12, 64, 3456}, NewBlockRuntimeID: 42,
			Flags: packet.BlockUpdateNetwork, Layer: 1,
		},
		0, 0,
	)
	emitPacket(
		"packet_update_block_synced",
		&packet.UpdateBlockSynced{
			Position: protocol.BlockPos{-12, 64, 3456}, NewBlockRuntimeID: 42,
			Flags: packet.BlockUpdateNetwork, Layer: 1,
			EntityUniqueID: 1<<40 + 25,
			TransitionType: packet.BlockToEntityTransition,
		},
		0, 0,
	)
	emitPacket(
		"packet_adventure_settings",
		&packet.AdventureSettings{
			Flags:                   packet.AdventureFlagAllowFlight,
			CommandPermissionLevel:  2,
			ActionPermissions:       packet.ActionPermissionMine | packet.ActionPermissionBuild,
			PermissionLevel:         packet.PermissionLevelMember,
			CustomStoredPermissions: 7, PlayerUniqueID: -99,
		},
		0, 0,
	)
	emitPacket(
		"packet_book_edit",
		&packet.BookEdit{
			InventorySlot: 2, ActionType: packet.BookActionReplacePage,
			PageNumber: 3, Text: "hello", PhotoName: "photo.png",
		},
		0, 0,
	)
	emitPacket(
		"packet_boss_event",
		&packet.BossEvent{
			BossEntityUniqueID: -7, PlayerUniqueID: -99,
			EventType: packet.BossEventShow, BossBarTitle: "Boss",
			FilteredBossBarTitle: "Boss", HealthPercentage: 0.75,
			Colour:  packet.BossEventColourPurple,
			Overlay: packet.BossEventOverlayNotched10,
		},
		0, 0,
	)
	emitPacket(
		"packet_update_soft_enum",
		&packet.UpdateSoftEnum{
			EnumType: "targets", Options: []string{"one", "two"},
			ActionType: packet.SoftEnumActionSet,
		},
		0, 0,
	)
	emitPacket(
		"packet_unlocked_recipes",
		&packet.UnlockedRecipes{
			UnlockType: packet.UnlockedRecipesTypeNewlyUnlocked,
			Recipes:    []string{"minecraft:bread", "minecraft:cake"},
		},
		0, 0,
	)
	emitPacket(
		"packet_trim_data",
		&packet.TrimData{
			Patterns: []protocol.TrimPattern{{
				ItemName:  "minecraft:spire_armor_trim_smithing_template",
				PatternID: "spire",
			}},
			Materials: []protocol.TrimMaterial{{
				MaterialID: "gold", Colour: "§6",
				ItemName: "minecraft:gold_ingot",
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_feature_registry",
		&packet.FeatureRegistry{
			Features: []protocol.GenerationFeature{{
				Name: "minecraft:test", JSON: []byte(`{"format_version":"1.0"}`),
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_dimension_data",
		&packet.DimensionData{
			Definitions: []protocol.DimensionDefinition{{
				Name: "custom:test", Range: [2]int32{320, -64},
				Generator: protocol.GeneratorOverworld, DimensionType: 1000,
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_server_store_info",
		&packet.ServerStoreInfo{
			StoreInfo: protocol.Option(protocol.StoreEntryPointInfo{
				StoreID: "store-id", StoreName: "Store",
			}),
		},
		0, 0,
	)
	emitPacket(
		"packet_server_presence_info",
		&packet.ServerPresenceInfo{
			PresenceInfo: protocol.Option(protocol.PresenceInfo{
				ExperienceName: protocol.Option("Experience"),
				WorldName:      protocol.Option("World"), RichPresenceID: "presence-id",
			}),
		},
		0, 0,
	)
	emitPacket(
		"packet_aim_assist_priority",
		&packet.CameraAimAssistActorPriority{
			PriorityData: []protocol.CameraAimAssistActorPriorityData{{
				PresetIndex: 1, CategoryIndex: 2, ActorIndex: 3, Priority: 4,
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_correct_move_prediction",
		&packet.CorrectPlayerMovePrediction{
			PredictionType:         packet.PredictionTypeVehicle,
			Position:               mgl32.Vec3{1.25, 2.5, 3.75},
			Delta:                  mgl32.Vec3{-0.25, 0.5, 0.75},
			Rotation:               mgl32.Vec2{45, 90},
			VehicleAngularVelocity: protocol.Option(float32(1.5)),
			OnGround:               true, Tick: 123456,
		},
		0, 0,
	)
	abilityData := protocol.AbilityData{
		EntityUniqueID: -99, PlayerPermissions: 1, CommandPermissions: 2,
		Layers: []protocol.AbilityLayer{{
			Type:      protocol.AbilityLayerTypeBase,
			Abilities: protocol.AbilityMayFly | protocol.AbilityFlying,
			Values:    protocol.AbilityMayFly, FlySpeed: 0.05,
			VerticalFlySpeed: 1, WalkSpeed: 0.1,
		}},
	}
	emitPacket(
		"packet_update_abilities",
		&packet.UpdateAbilities{AbilityData: abilityData},
		0, 0,
	)
	emitPacket(
		"packet_client_cheat_ability",
		&packet.ClientCheatAbility{AbilityData: abilityData},
		0, 0,
	)
	emitPacket(
		"packet_container_registry_cleanup",
		&packet.ContainerRegistryCleanup{
			RemovedContainers: []protocol.FullContainerName{{
				ContainerID: 0, DynamicContainerID: protocol.Option(uint32(42)),
			}},
		},
		0, 0,
	)
	emitPacket(
		"packet_game_rules_changed",
		&packet.GameRulesChanged{
			GameRules: []protocol.GameRule{
				{Name: "showcoordinates", CanBeModifiedByPlayer: true, Value: true},
				{Name: "randomtickspeed", Value: uint32(3)},
				{Name: "playerssleepingpercentage", Value: float32(50.5)},
			},
		},
		0, 0,
	)
	emitPacket(
		"packet_pack_setting_float",
		&packet.ServerBoundPackSettingChange{
			PackID:      packUUID,
			PackSetting: protocol.PackSetting{Name: "scale", Value: float32(1.5)},
		},
		0, 0,
	)
	emitPacket(
		"packet_pack_setting_bool",
		&packet.ServerBoundPackSettingChange{
			PackID:      packUUID,
			PackSetting: protocol.PackSetting{Name: "enabled", Value: true},
		},
		0, 0,
	)
	emitPacket(
		"packet_pack_setting_string",
		&packet.ServerBoundPackSettingChange{
			PackID:      packUUID,
			PackSetting: protocol.PackSetting{Name: "mode", Value: "hard"},
		},
		0, 0,
	)
	emitPacket(
		"packet_request_ability_bool",
		&packet.RequestAbility{Ability: packet.AbilityFlying, Value: true},
		0, 0,
	)
	emitPacket(
		"packet_request_ability_float",
		&packet.RequestAbility{Ability: packet.AbilityFlySpeed, Value: float32(0.15)},
		0, 0,
	)
	emitPacket(
		"packet_data_store_double",
		&packet.ServerBoundDataStore{
			Update: protocol.DataStoreUpdate{
				DataStoreName: "settings", Property: "scale", Path: "ui",
				ControlType: protocol.DataStoreControlDouble, DoubleValue: 1.5,
				PropertyUpdateCount: 2, PathUpdateCount: 3,
			},
		},
		0, 0,
	)
	emitPacket(
		"packet_data_store_bool",
		&packet.ServerBoundDataStore{
			Update: protocol.DataStoreUpdate{
				DataStoreName: "settings", Property: "enabled", Path: "ui",
				ControlType: protocol.DataStoreControlBoolean, BoolValue: true,
				PropertyUpdateCount: 2, PathUpdateCount: 3,
			},
		},
		0, 0,
	)
	emitPacket(
		"packet_data_store_string",
		&packet.ServerBoundDataStore{
			Update: protocol.DataStoreUpdate{
				DataStoreName: "settings", Property: "mode", Path: "ui",
				ControlType: protocol.DataStoreControlString, StringValue: "hard",
				PropertyUpdateCount: 2, PathUpdateCount: 3,
			},
		},
		0, 0,
	)
	emitPacket(
		"packet_client_data_store",
		&packet.ClientBoundDataStore{
			Updates: []protocol.DataStoreChangeEntry{
				{
					ChangeType: protocol.DataStoreChangeTypeUpdate,
					Update: protocol.DataStoreUpdate{
						DataStoreName: "settings", Property: "mode", Path: "ui",
						ControlType: protocol.DataStoreControlString,
						StringValue: "hard", PropertyUpdateCount: 2,
						PathUpdateCount: 3,
					},
				},
				{
					ChangeType: protocol.DataStoreChangeTypeChange,
					Change: protocol.DataStoreChange{
						DataStoreName: "state", Property: "nested", UpdateCount: 4,
						NewValue: protocol.DataStorePropertyValue{
							Type: protocol.DataStorePropertyTypeMap,
							MapValue: []protocol.DataStoreMapEntry{{
								Key: "items",
								Value: protocol.DataStorePropertyValue{
									Type: protocol.DataStorePropertyTypeList,
									ListValue: []protocol.DataStorePropertyValue{
										{Type: protocol.DataStorePropertyTypeString, StringValue: "one"},
										{Type: protocol.DataStorePropertyTypeInt64, Int64Value: -7},
									},
								},
							}},
						},
					},
				},
				{
					ChangeType: protocol.DataStoreChangeTypeRemoval,
					Removal:    protocol.DataStoreRemoval{DataStoreName: "old"},
				},
			},
		},
		0, 0,
	)
	actorFlags := protocol.NewBitset(protocol.EntityDataFlagCount)
	actorFlags.Set(0)
	actorFlags.Set(64)
	actorFlags.Set(129)
	emitPacket(
		"packet_client_movement_prediction_sync",
		&packet.ClientMovementPredictionSync{
			ActorFlags: actorFlags,
			BoundingBoxScale: 1, BoundingBoxWidth: 0.6, BoundingBoxHeight: 1.8,
			MovementSpeed: 0.1, UnderwaterMovementSpeed: 0.02,
			LavaMovementSpeed: 0.03, JumpStrength: 0.42,
			Health: 20, Hunger: 18, FrictionModifier: 0.91,
			Bounciness: 0.2, AirDragModifier: 0.98,
			EntityUniqueID: -99, Flying: true,
		},
		0, 0,
	)
	emitPacket(
		"packet_graphics_override_parameter",
		&packet.GraphicsOverrideParameter{
			Values: []protocol.ParameterKeyframeValue{
				{Time: 0, Value: mgl32.Vec3{0.1, 0.2, 0.3}},
				{Time: 1, Value: mgl32.Vec3{0.4, 0.5, 0.6}},
			},
			FloatValue: protocol.Option(float32(0.75)),
			Vec3Value: protocol.Option(mgl32.Vec3{1, 2, 3}),
			BiomeIdentifier: "minecraft:plains",
			PlayerIdentifier: protocol.Option("player"),
			ParameterType: protocol.GraphicsOverrideParameterTypeSunColor,
			Reset: false,
		},
		0, 0,
	)
	emitPacket(
		"packet_locator_bar",
		&packet.LocatorBar{
			Waypoints: []protocol.LocatorBarWaypoint{{
				GroupHandle: packUUID,
				Waypoint: protocol.Waypoint{
					UpdateFlag: protocol.WaypointUpdateFlagVisible |
						protocol.WaypointUpdateFlagPosition |
						protocol.WaypointUpdateFlagTextureID |
						protocol.WaypointUpdateFlagColour |
						protocol.WaypointUpdateFlagClientPositionAuthority |
						protocol.WaypointUpdateFlagActorUniqueID,
					Visible: protocol.Option(true),
					WorldPosition: protocol.Option(protocol.WaypointWorldPosition{
						Position: mgl32.Vec3{1.25, 64, -3.5}, DimensionID: 1,
					}),
					TexturePath: protocol.Option("textures/ui/waypoint"),
					IconSize: protocol.Option(mgl32.Vec2{16, 16}),
					Colour: protocol.Option(int32(0x112233)),
					ClientPositionAuthority: protocol.Option(false),
					ActorUniqueID: protocol.Option(int64(-99)),
				},
				Action: protocol.WaypointActionAdd,
			}},
		},
		0, 0,
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
