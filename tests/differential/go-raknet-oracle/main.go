package main

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"net"
	"net/netip"
	"os"
	"strconv"
	"time"

	raknet "github.com/sandertv/go-raknet"
	"github.com/sandertv/go-raknet/internal/message"
)

func crossRuntimePayload(size int) []byte {
	payload := make([]byte, size)
	for index := range payload {
		payload[index] = byte(index*31 + 7)
	}
	return payload
}

func emit(name string, data []byte, err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", name, err)
		os.Exit(1)
	}
	fmt.Printf("%s %s\n", name, hex.EncodeToString(data))
}

func fixtures() {
	address := netip.MustParseAddrPort("127.0.0.1:19132")

	data, err := (&message.ConnectedPing{
		PingTime: 0x0102030405060708,
	}).MarshalBinary()
	emit("connected_ping", data, err)

	data, err = (&message.ConnectedPong{
		PingTime: 0x0102030405060708,
		PongTime: 0x1112131415161718,
	}).MarshalBinary()
	emit("connected_pong", data, err)

	data, err = (&message.ConnectionRequest{
		ClientGUID:  -0x010203040506070,
		RequestTime: 0x2122232425262728,
		Secure:      true,
	}).MarshalBinary()
	emit("connection_request", data, err)

	data, err = (&message.UnconnectedPing{
		PingTime:   0x3132333435363738,
		ClientGUID: -0x111213141516171,
	}).MarshalBinary()
	emit("unconnected_ping", data, err)

	data, err = (&message.UnconnectedPong{
		PingTime:   0x4142434445464748,
		ServerGUID: -0x212223242526272,
		Data:       []byte("MCPE;fixture"),
	}).MarshalBinary()
	emit("unconnected_pong", data, err)

	data, err = (&message.IncompatibleProtocolVersion{
		ServerProtocol: 11,
		ServerGUID:     -0x313233343536373,
	}).MarshalBinary()
	emit("incompatible_protocol", data, err)

	data, err = (&message.OpenConnectionReply1{
		ServerGUID:        -0x414243444546474,
		ServerHasSecurity: true,
		Cookie:            0xa1b2c3d4,
		MTU:               1492,
	}).MarshalBinary()
	emit("open_connection_reply_1", data, err)

	data, err = (&message.OpenConnectionRequest1{
		ClientProtocol: 11,
		MTU:            1200,
	}).MarshalBinary()
	emit("open_connection_request_1", data, err)

	data, err = (&message.OpenConnectionRequest2{
		ServerAddress:     address,
		MTU:               1200,
		ClientGUID:        -0x515253545556575,
		ServerHasSecurity: true,
		Cookie:            0xb1c2d3e4,
	}).MarshalBinary()
	emit("open_connection_request_2", data, err)

	data, err = (&message.OpenConnectionReply2{
		ServerGUID:    -0x616263646566676,
		ClientAddress: address,
		MTU:           1200,
		DoSecurity:    false,
	}).MarshalBinary()
	emit("open_connection_reply_2", data, err)

	data, err = (&message.ConnectionRequestAccepted{
		ClientAddress: address,
		SystemIndex:   3,
		PingTime:      0x5152535455565758,
		PongTime:      0x6162636465666768,
	}).MarshalBinary()
	emit("connection_request_accepted", data, err)

	data, err = (&message.NewIncomingConnection{
		ServerAddress: address,
		PingTime:      0x7172737475767778,
		PongTime:      0x0101020203030404,
	}).MarshalBinary()
	emit("new_incoming_connection", data, err)
}

func serveEcho() {
	listener, err := raknet.Listen("127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	defer listener.Close()
	fmt.Println(listener.Addr().String())

	conn, err := listener.Accept()
	if err != nil {
		panic(err)
	}
	buffer := make([]byte, 65536)
	count, err := conn.Read(buffer)
	if err != nil {
		panic(err)
	}
	if !bytes.Equal(buffer[:count], crossRuntimePayload(count)) {
		panic("unexpected Odin payload")
	}
	if _, err = conn.Write(buffer[:count]); err != nil {
		panic(err)
	}
	_ = conn.Close()
	time.Sleep(1500 * time.Millisecond)
}

func dialEcho(address string, payloadSize int) {
	conn, err := raknet.DialTimeout(address, 3*time.Second)
	if err != nil {
		panic(err)
	}
	defer conn.Close()
	payload := crossRuntimePayload(payloadSize)
	if _, err = conn.Write(payload); err != nil {
		panic(err)
	}
	buffer := make([]byte, 65536)
	count, err := conn.Read(buffer)
	if err != nil {
		panic(err)
	}
	if !bytes.Equal(buffer[:count], payload) {
		panic("unexpected Odin echo")
	}
	fmt.Println("go-client-ok")
}

func udpProxy(targetAddress string, dropPercent int, chaos bool) {
	target, err := net.ResolveUDPAddr("udp", targetAddress)
	if err != nil {
		panic(err)
	}
	socket, err := net.ListenUDP("udp", &net.UDPAddr{
		IP: net.IPv4(127, 0, 0, 1),
	})
	if err != nil {
		panic(err)
	}
	defer socket.Close()
	fmt.Println(socket.LocalAddr().String())

	buffer := make([]byte, 2048)
	var client *net.UDPAddr
	var heldPacket []byte
	var heldDestination *net.UDPAddr
	packetIndex := 0
	clientDropState := uint32(0x6d2b79f5)
	serverDropState := uint32(0x1b56c4e9)
	clientPacketCount := 0
	serverPacketCount := 0
	for {
		if heldPacket != nil {
			if err = socket.SetReadDeadline(time.Now().Add(10 * time.Millisecond)); err != nil {
				panic(err)
			}
		} else if err = socket.SetReadDeadline(time.Time{}); err != nil {
			panic(err)
		}
		count, source, readErr := socket.ReadFromUDP(buffer)
		if readErr != nil {
			if timeout, ok := readErr.(net.Error); ok && timeout.Timeout() && heldPacket != nil {
				if _, err = socket.WriteToUDP(heldPacket, heldDestination); err != nil {
					panic(err)
				}
				heldPacket = nil
				heldDestination = nil
				continue
			}
			panic(readErr)
		}
		packetIndex++
		destination := target
		fromServer := source.String() == target.String()
		if fromServer {
			if client == nil {
				continue
			}
			destination = client
		} else {
			client = source
		}
		dropState := &clientDropState
		directionPacketCount := &clientPacketCount
		if fromServer {
			dropState = &serverDropState
			directionPacketCount = &serverPacketCount
		}
		*directionPacketCount++
		if *directionPacketCount > 12 {
			*dropState = *dropState*1664525 + 1013904223
			if dropPercent > 0 && int(*dropState%100) < dropPercent {
				continue
			}
		}
		if chaos && packetIndex%5 == 0 && heldPacket == nil {
			heldPacket = append([]byte(nil), buffer[:count]...)
			destinationCopy := *destination
			heldDestination = &destinationCopy
			continue
		}
		if _, err = socket.WriteToUDP(buffer[:count], destination); err != nil {
			panic(err)
		}
		if chaos && packetIndex%7 == 0 {
			if _, err = socket.WriteToUDP(buffer[:count], destination); err != nil {
				panic(err)
			}
		}
		if heldPacket != nil {
			if _, err = socket.WriteToUDP(heldPacket, heldDestination); err != nil {
				panic(err)
			}
			heldPacket = nil
			heldDestination = nil
		}
	}
}

func main() {
	if len(os.Args) == 1 || os.Args[1] == "fixtures" {
		fixtures()
		return
	}
	switch os.Args[1] {
	case "serve-echo":
		serveEcho()
	case "dial-echo":
		if len(os.Args) != 3 && len(os.Args) != 4 {
			panic("usage: go-oracle dial-echo <address> [payload-size]")
		}
		payloadSize := len("mcpe-odin-cross-runtime")
		if len(os.Args) == 4 {
			var err error
			payloadSize, err = strconv.Atoi(os.Args[3])
			if err != nil || payloadSize < 1 || payloadSize > 65536 {
				panic("invalid payload-size")
			}
		}
		dialEcho(os.Args[2], payloadSize)
	case "udp-proxy":
		if len(os.Args) != 4 && len(os.Args) != 5 {
			panic("usage: go-oracle udp-proxy <target> <drop-percent> [chaos]")
		}
		dropPercent, err := strconv.Atoi(os.Args[3])
		if err != nil || dropPercent < 0 || dropPercent > 100 {
			panic("invalid drop-percent")
		}
		chaos := len(os.Args) == 5 && os.Args[4] == "chaos"
		udpProxy(os.Args[2], dropPercent, chaos)
	default:
		panic("unknown operation")
	}
}
