// Package checkout exposes the HTTP surface that authorises a payment.
package checkout

import (
	"encoding/json"
	"net/http"

	"github.com/chandler767/AI-Lied-About-Your-Test/internal/pricing"
)

type Request struct {
	Lines      []pricing.Line   `json:"lines"`
	DiscountPc pricing.Discount `json:"discount_pct"`
}

type Response struct {
	TotalCents int    `json:"total_cents"`
	Currency   string `json:"currency"`
}

// Handler authorises a cart and returns the amount charged.
func Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /checkout", func(w http.ResponseWriter, r *http.Request) {
		var req Request
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		if len(req.Lines) == 0 {
			http.Error(w, "empty cart", http.StatusBadRequest)
			return
		}
		resp := Response{
			TotalCents: pricing.CartTotal(req.Lines, req.DiscountPc),
			Currency:   "USD",
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})
	return mux
}
