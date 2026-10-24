package main

import "testing"

func TestExtractDirectPathKeepsSignature(t *testing.T) {
	for in, want := range map[string]string{
		"https://mmg.whatsapp.net/v/t62.7119-24/1_n.enc?ccb=11-4&oh=AB&oe=CD&_nc_sid=5e": "/v/t62.7119-24/1_n.enc?ccb=11-4&oh=AB&oe=CD&_nc_sid=5e",
		"https://mmg.whatsapp.net/v/t62.7118-24/2_n.enc":                                 "/v/t62.7118-24/2_n.enc",
		"not-a-url": "not-a-url",
	} {
		if got := extractDirectPathFromURL(in); got != want {
			t.Errorf("%s: got %s, want %s", in, got, want)
		}
	}
}
