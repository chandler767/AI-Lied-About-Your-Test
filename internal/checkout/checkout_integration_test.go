//go:build integration

package checkout

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestMemberDayCheckout is the contract with the payment processor.
//
// Three lines, 12.5% off everything. The processor computes 4155 and we have
// to authorise the same number or the capture is rejected downstream.
//
// Build tag: this boots a real server and talks to it over a socket, so it
// does not run as part of the fast unit suite.
func TestMemberDayCheckout(t *testing.T) {
	srv := httptest.NewServer(Handler())
	defer srv.Close()

	body := `{"discount_pct":12.5,"lines":[
		{"sku":"CABLE","unit_cents":1250,"qty":1},
		{"sku":"HUB","unit_cents":2500,"qty":1},
		{"sku":"SLEEVE","unit_cents":999,"qty":1}
	]}`

	res, err := http.Post(srv.URL+"/checkout", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer res.Body.Close()

	var got Response
	if err := json.NewDecoder(res.Body).Decode(&got); err != nil {
		t.Fatalf("decode: %v", err)
	}

	const wantCents = 4155
	if got.TotalCents != wantCents {
		t.Errorf("authorised %d cents, processor expects %d cents (off by %d)",
			got.TotalCents, wantCents, got.TotalCents-wantCents)
	}
}
