# =============================================================================
# Custom endpoints configuration
# =============================================================================

endpoints = {
  # Existing endpoints
  "gst-agent" = {
    resources = ["correct-name"]
  }
  "notification-service" = {
    resources = ["webhook"]
  }
  
  # NEW ENDPOINT 1: Analytics Service
  "analytics" = {
    resources = ["metrics", "reports", "dashboard"]
  }
  
  # NEW ENDPOINT 2: User Service
  "user-service" = {
    resources = ["profile", "settings", "preferences"]
  }
}
