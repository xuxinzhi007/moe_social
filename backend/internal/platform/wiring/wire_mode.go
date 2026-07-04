package runserver

import "backend/internal/platform/moewiring"

func kratosPilotBaseURL() string {
	return moewiring.KratosPilotBaseURL()
}

func kratosAdminInsightsEnabled() bool {
	return moewiring.KratosAdminInsightsHTTPEnabled()
}

func kratosAdminHTTPEnabled() bool {
	return moewiring.KratosAdminHTTPEnabled()
}

func kratosVipHTTPEnabled() bool {
	return moewiring.KratosVipHTTPEnabled()
}
