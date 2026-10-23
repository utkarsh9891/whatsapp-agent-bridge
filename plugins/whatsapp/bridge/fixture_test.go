package main

import (
	"os"
	"testing"
	"time"
)

// TestWriteFixture writes messages.db through the real MessageStore so the
// Python digest tests read exactly what the bridge writes. Runs only when
// FIXTURE_HOME is set (see server/tests).
func TestWriteFixture(t *testing.T) {
	home := os.Getenv("FIXTURE_HOME")
	if home == "" {
		t.Skip("FIXTURE_HOME not set")
	}
	t.Setenv("WA_HOME", home)
	if err := ensureDirs(); err != nil {
		t.Fatal(err)
	}
	s, err := NewMessageStore()
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()

	ist := time.FixedZone("IST", 5*3600+1800)
	now := time.Now().In(ist).Truncate(time.Second)
	ago := func(h float64) time.Time { return now.Add(-time.Duration(h * float64(time.Hour))) }
	must := func(err error) {
		if err != nil {
			t.Fatal(err)
		}
	}

	must(s.StoreChat("100@g.us", "Field Ops North", ago(1)))
	must(s.StoreChat("200@g.us", "Field Ops South", ago(2)))
	must(s.StoreChat("300@g.us", "Not Allowlisted Busy", ago(0.5)))
	must(s.StoreChat("400@g.us", "Old Group", ago(100)))

	msg := func(id, chat, sender, text string, at time.Time, me bool) {
		must(s.StoreMessage(id, chat, sender, text, at, me, "", "", "", nil, nil, nil, 0))
	}
	// North: I replied, then two new messages, one mentioning me and one with a keyword
	msg("n1", "100@g.us", "911111", "morning all", ago(5), false)
	msg("n2", "100@g.us", "919999", "on it", ago(4), true)
	msg("n3", "100@g.us", "912222", "@919999 merchant onboarding failed for 3 leads", ago(2), false)
	msg("n4", "100@g.us", "913333", "app is down at my location", ago(1), false)
	// South: never replied, one old message outside the window
	msg("s0", "200@g.us", "914444", "last week stuff", ago(48), false)
	msg("s1", "200@g.us", "914444", "all good here", ago(2), false)
	must(s.StoreMessage("s2", "200@g.us", "915555", "", ago(1.5), false, "image", "image_x.jpg", "", nil, nil, nil, 0))
}
