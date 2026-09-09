package checkout

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandlerRejectsEmptyCart(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/checkout", strings.NewReader(`{"lines":[]}`))
	Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestHandlerRejectsGarbage(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/checkout", strings.NewReader(`not json`))
	Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}
