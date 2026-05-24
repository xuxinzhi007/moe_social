package handler

import "net/http"

func (h *Handler) opsLandingFeedback(w http.ResponseWriter, r *http.Request) {
	h.forwardToAPI(w, r, "/api/ops/landing/feedback")
}
