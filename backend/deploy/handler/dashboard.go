package handler

// DashboardPath is the default page when explicitly opening the Agent in a browser.
func DashboardPath(workspaceRoot string) string {
	_ = workspaceRoot
	return "/devtools.html"
}
