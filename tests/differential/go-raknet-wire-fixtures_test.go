package raknet

import (
	"bytes"
	"fmt"
	"testing"
)

func TestMcpeOdinWireFixtures(t *testing.T) {
	var buffer bytes.Buffer
	(&packet{
		reliability:  reliabilityReliableOrdered,
		messageIndex: 0x010203,
		orderIndex:   0x040506,
		content:      []byte{0x11, 0x22, 0x33},
		split:        true,
		splitCount:   3,
		splitIndex:   1,
		splitID:      0x0708,
	}).write(&buffer)
	fmt.Printf("encapsulated_packet %x\n", buffer.Bytes())

	buffer.Reset()
	(&packet{
		reliability: reliability(5),
		content:     []byte{0x42},
	}).write(&buffer)
	fmt.Printf("reserved_reliability_packet %x\n", buffer.Bytes())

	buffer.Reset()
	buffer.WriteByte(bitFlagACK | bitFlagDatagram)
	ack := acknowledgement{packets: []uint24{1, 1, 2, 8}}
	ack.write(&buffer, 1400)
	fmt.Printf("acknowledgement %x\n", buffer.Bytes())
}
