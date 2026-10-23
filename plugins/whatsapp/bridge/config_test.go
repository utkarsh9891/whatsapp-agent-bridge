package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func setHome(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("WA_HOME", dir)
	cfgMu.Lock()
	cfg, cfgMtime = Config{}, time.Time{}
	cfgMu.Unlock()
	if err := ensureDirs(); err != nil {
		t.Fatal(err)
	}
	return dir
}

func writeConfig(t *testing.T, body string) {
	t.Helper()
	path := waPath("config.json")
	if err := os.WriteFile(path, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	// Force a distinct mtime so the reload is observed.
	future := time.Now().Add(time.Duration(len(body)) * time.Second)
	os.Chtimes(path, future, future)
}

func TestIsAllowed(t *testing.T) {
	setHome(t)
	if isAllowed("1@g.us") {
		t.Fatal("no config must allow nothing")
	}
	writeConfig(t, `{"allow_chats":["1@g.us"]}`)
	if !isAllowed("1@g.us") || isAllowed("2@g.us") || isAllowed("91@s.whatsapp.net") {
		t.Fatal("allowlist not applied")
	}
	writeConfig(t, `{"allow_chats":[],"allow_direct_chats":true}`)
	if isAllowed("1@g.us") || !isAllowed("91@s.whatsapp.net") {
		t.Fatal("allow_direct_chats not applied or config not reloaded")
	}
	writeConfig(t, `{not json`)
	if !isAllowed("91@s.whatsapp.net") {
		t.Fatal("invalid config must keep the previous one")
	}
}

func TestEnsureDirsPrivate(t *testing.T) {
	dir := setHome(t)
	for _, d := range []string{dir, filepath.Join(dir, "media"), filepath.Join(dir, "outbox")} {
		st, err := os.Stat(d)
		if err != nil || st.Mode().Perm() != 0700 {
			t.Fatalf("%s: want 0700, got %v (%v)", d, st.Mode().Perm(), err)
		}
	}
}

func TestSafeName(t *testing.T) {
	for in, want := range map[string]string{
		"../../.zshrc":         ".zshrc",
		"/etc/passwd":          "passwd",
		"..":                   "file",
		"":                     "file",
		"a b;rm -rf.pdf":       "a_b_rm_-rf.pdf",
		"120363@g.us":          "120363@g.us",
		"91:12@s.whatsapp.net": "91_12@s.whatsapp.net",
	} {
		if got := safeName(in); got != want {
			t.Errorf("safeName(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestOutboxPath(t *testing.T) {
	dir := setHome(t)
	inside := filepath.Join(dir, "outbox", "ok.png")
	os.WriteFile(inside, []byte("x"), 0600)
	if _, err := outboxPath(inside); err != nil {
		t.Fatalf("file in outbox rejected: %v", err)
	}

	secret := filepath.Join(dir, "token")
	os.WriteFile(secret, []byte("s"), 0600)
	if _, err := outboxPath(secret); err == nil {
		t.Fatal("file outside outbox accepted")
	}
	if _, err := outboxPath(filepath.Join(dir, "outbox", "..", "token")); err == nil {
		t.Fatal("dot-dot escape accepted")
	}
	link := filepath.Join(dir, "outbox", "link")
	os.Symlink(secret, link)
	if _, err := outboxPath(link); err == nil {
		t.Fatal("symlink escape accepted")
	}
}

func TestLoadTokenStableAndPrivate(t *testing.T) {
	setHome(t)
	a, err := loadToken()
	if err != nil || len(a) != 64 {
		t.Fatalf("token %q err %v", a, err)
	}
	b, _ := loadToken()
	if a != b {
		t.Fatal("token not reused")
	}
	if st, _ := os.Stat(waPath("token")); st.Mode().Perm() != 0600 {
		t.Fatalf("token perms %v", st.Mode().Perm())
	}
}

func TestRequireAuth(t *testing.T) {
	h := requireAuth("secret", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	cases := []struct {
		auth, ctype string
		want        int
	}{
		{"", "application/json", http.StatusUnauthorized},
		{"Bearer wrong", "application/json", http.StatusUnauthorized},
		{"Bearer secret", "text/plain", http.StatusUnsupportedMediaType},
		{"Bearer secret", "application/json", http.StatusOK},
	}
	for _, c := range cases {
		r := httptest.NewRequest(http.MethodPost, "/api/send", nil)
		if c.auth != "" {
			r.Header.Set("Authorization", c.auth)
		}
		r.Header.Set("Content-Type", c.ctype)
		w := httptest.NewRecorder()
		h(w, r)
		if w.Code != c.want {
			t.Errorf("auth=%q ctype=%q: got %d want %d", c.auth, c.ctype, w.Code, c.want)
		}
	}
}

func TestWriteQRPNG(t *testing.T) {
	setHome(t)
	path, err := writeQRPNG("2@abc,def,ghi")
	if err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if len(data) < 8 || string(data[1:4]) != "PNG" {
		t.Fatal("not a PNG")
	}
}
