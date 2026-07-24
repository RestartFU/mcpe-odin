package raknet

import (
	"bytes"
	"testing"
)

var benchmarkPacketSink packet
var benchmarkFragmentsSink [][]byte

func BenchmarkPacketDecode1KiB(b *testing.B) {
	content := make([]byte, 1024)
	expected := packet{
		reliability:  reliabilityReliableOrdered,
		messageIndex: 7,
		orderIndex:   11,
		content:      content,
	}
	var buffer bytes.Buffer
	expected.write(&buffer)
	data := buffer.Bytes()

	b.ReportAllocs()
	b.SetBytes(int64(len(data)))
	b.ResetTimer()
	for range b.N {
		var decoded packet
		if _, err := decoded.read(data); err != nil {
			b.Fatal(err)
		}
		benchmarkPacketSink = decoded
	}
}

func BenchmarkFragment64KiB(b *testing.B) {
	payload := make([]byte, 65536)

	b.ReportAllocs()
	b.SetBytes(int64(len(payload)))
	b.ResetTimer()
	for range b.N {
		benchmarkFragmentsSink = split(payload, 1400)
	}
}
