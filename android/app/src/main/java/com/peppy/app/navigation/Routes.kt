package com.peppy.app.navigation

object Routes {
    const val WELCOME = "welcome"
    const val LOGIN = "login"
    const val REGISTER = "register"
    const val MAIN = "main"

    // Protocol routes
    const val PROTOCOL_DETAIL = "protocol/{protocolId}"
    const val PROTOCOL_CREATE = "protocol/create"
    const val PROTOCOL_EDIT = "protocol/{protocolId}/edit"

    fun protocolDetail(protocolId: String) = "protocol/$protocolId"
    fun protocolEdit(protocolId: String) = "protocol/$protocolId/edit"
}

object MainTabs {
    const val DASHBOARD = "dashboard"
    const val CHECKIN = "checkin"
    const val PROTOCOLS = "protocols"
    const val INSIGHTS = "insights"
    const val SETTINGS = "settings"
}
