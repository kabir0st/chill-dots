import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Settings
import qs.Components
import qs.Services

Item {
    id: root
    width: Settings.settings.wifiEnabled ? 22 : 0
    height: Settings.settings.wifiEnabled ? 22 : 0

    property bool menuVisible: false
    property string passwordPromptSsid: ""
    property string passwordInput: ""
    property bool showPasswordPrompt: false
    // Enterprise 802.1X authentication fields
    property bool showEnterprisePrompt: false
    property string enterprisePromptSsid: ""
    property string enterpriseIdentity: ""
    property string enterpriseEapMethod: "peap"
    property string enterprisePhase2Auth: "mschapv2"
    // Certificate auth fields
    property string enterpriseCaCert: ""
    property string enterpriseClientCert: ""
    property string enterprisePrivateKey: ""
    property string enterprisePrivateKeyPassword: ""
    property string enterpriseAnonymousIdentity: ""
    property string enterpriseDomainSuffixMatch: ""
    // Detail panel (right-click)
    property string detailPanelSsid: ""
    property bool showDetailPanel: false

    // Network is now a singleton service — no need to instantiate
    property var network: Network

    // WiFi icon/button
    Item {
        id: wifiIcon
        width: 22; height: 22
        visible: Settings.settings.wifiEnabled

        property int currentSignal: {
            let maxSignal = 0;
            for (const net in network.networks) {
                if (network.networks[net].connected && network.networks[net].signal > maxSignal) {
                    maxSignal = network.networks[net].signal;
                }
            }
            return maxSignal;
        }

        property bool isConnected: {
            for (const net in network.networks) {
                if (network.networks[net].connected) {
                    return true;
                }
            }
            return false;
        }

        // Signal strength drives the color: cyan when strong, amber when weak, red when down
        property color statusColor: {
            if (!isConnected)
                return IconPalette.wifiOff;
            if (currentSignal >= 60)
                return IconPalette.wifiStrong;
            if (currentSignal >= 35)
                return IconPalette.wifiMedium;
            return IconPalette.wifiWeak;
        }

        Text {
            id: wifiText
            anchors.centerIn: parent
            text: parent.isConnected ? network.signalIcon(parent.currentSignal) : "wifi_off"
            font.family: mouseAreaWifi.containsMouse ? "Material Symbols Rounded" : "Material Symbols Outlined"
            font.pixelSize: 16 * Theme.scale(Screen)
            color: mouseAreaWifi.containsMouse ? IconPalette.hover(wifiIcon.statusColor) : wifiIcon.statusColor

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        MouseArea {
            id: mouseAreaWifi
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!wifiMenuLoader.active) {
                    wifiMenuLoader.loading = true;
                }
                if (wifiMenuLoader.item) {
                    wifiMenuLoader.item.visible = !wifiMenuLoader.item.visible;
                    if (wifiMenuLoader.item.visible) {
                        network.onMenuOpened();
                    } else {
                        network.onMenuClosed();
                    }
                }
            }
            onEntered: wifiTooltip.tooltipVisible = true
            onExited: wifiTooltip.tooltipVisible = false
        }
    }

    StyledTooltip {
        id: wifiTooltip
        text: "WiFi Networks"
        positionAbove: false
        tooltipVisible: false
        targetItem: wifiIcon
        delay: 200
    }

    // LazyLoader for WiFi menu
    LazyLoader {
        id: wifiMenuLoader
        loading: false
        component: PanelWindow {
            id: wifiMenu
            implicitWidth: 320
            implicitHeight: 480
            visible: false
            color: "transparent"
            anchors.top: true
            anchors.right: true
            margins.right: 0
            margins.top: 0
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                anchors.fill: parent
                color: Theme.backgroundPrimary
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "wifi"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24 * Theme.scale(Screen)
                            color: Theme.accentPrimary
                        }

                        Text {
                            text: "WiFi Networks"
                            font.pixelSize: 18 * Theme.scale(Screen)
                            font.bold: true
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: "refresh"
                            onClicked: network.refreshNetworks()
                        }

                        IconButton {
                            icon: "close"
                            onClicked: {
                                wifiMenu.visible = false;
                                network.onMenuClosed();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.12
                    }

                    ListView {
                        id: networkList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: Object.values(network.networks)
                        spacing: 8
                        clip: true

                        delegate: Item {
                            width: parent.width
                            clip: true
                            height: {
                                var h = 48;
                                if (modelData.ssid === passwordPromptSsid && showPasswordPrompt)
                                    h = 108;
                                else if (modelData.ssid === root.enterprisePromptSsid && root.showEnterprisePrompt) {
                                    // Base: EAP selector + identity + password + connect btn ≈ 228
                                    // TLS adds: client cert, private key, private key password (3 rows × 38) + hides phase2
                                    // All methods: CA cert, anonymous identity, domain match (3 rows × 38)
                                    h = 228 + 114; // base + common cert fields
                                    if (root.enterpriseEapMethod === "tls")
                                        h += 114; // client cert + private key + private key password
                                }
                                if (modelData.ssid === root.detailPanelSsid && root.showDetailPanel)
                                    h += barDetailPanelContent.implicitHeight + 20;
                                return h;
                            }
                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 0

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    radius: 8
                                    color: modelData.connected ? Qt.rgba(Theme.accentPrimary.r, Theme.accentPrimary.g, Theme.accentPrimary.b, 0.44) : (networkMouseArea.containsMouse ? Theme.highlight : "transparent")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: network.signalIcon(modelData.signal)
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18 * Theme.scale(Screen)
                                            color: networkMouseArea.containsMouse ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : (modelData.connected ? Theme.accentPrimary : Theme.textSecondary)
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: modelData.ssid || "Unknown Network"
                                                color: networkMouseArea.containsMouse ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : (modelData.connected ? Theme.accentPrimary : Theme.textPrimary)
                                                font.pixelSize: 14 * Theme.scale(Screen)
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.security && modelData.security !== "--" ? modelData.security : "Open"
                                                color: networkMouseArea.containsMouse ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : (modelData.connected ? Theme.accentPrimary : Theme.textSecondary)
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                visible: network.connectStatusSsid === modelData.ssid && network.connectStatus === "error" && network.connectError.length > 0
                                                text: network.connectError
                                                color: Theme.error
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Item {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            visible: network.connectStatusSsid === modelData.ssid && (network.connectStatus !== "" || network.connectingSsid === modelData.ssid)

                                            Spinner {
                                                visible: network.connectingSsid === modelData.ssid
                                                running: network.connectingSsid === modelData.ssid
                                                color: Theme.accentPrimary
                                                anchors.centerIn: parent
                                                size: 22
                                            }

                                            Text {
                                                visible: network.connectStatus === "success" && !network.connectingSsid
                                                text: "check_circle"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 18 * Theme.scale(Screen)
                                                color: "#43a047"
                                                anchors.centerIn: parent
                                            }

                                            Text {
                                                visible: network.connectStatus === "error" && !network.connectingSsid
                                                text: "error"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 18 * Theme.scale(Screen)
                                                color: Theme.error
                                                anchors.centerIn: parent
                                            }
                                        }

                                        Text {
                                            visible: modelData.connected
                                            text: "connected"
                                            color: networkMouseArea.containsMouse ? (Settings.settings.lightMode ? Theme.textPrimary : Theme.backgroundPrimary) : Theme.accentPrimary
                                            font.pixelSize: 11 * Theme.scale(Screen)
                                        }
                                    }

                                    MouseArea {
                                        id: networkMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                // Right-click: toggle detail/info panel
                                                if (modelData.existing || modelData.connected) {
                                                    if (root.showDetailPanel && root.detailPanelSsid === modelData.ssid) {
                                                        // Same network: collapse
                                                        root.showDetailPanel = false;
                                                        root.detailPanelSsid = "";
                                                    } else {
                                                        root.showDetailPanel = true;
                                                        root.detailPanelSsid = modelData.ssid;
                                                        network.fetchConnectionDetails(modelData.ssid);
                                                    }
                                                    passwordPromptSsid = "";
                                                    showPasswordPrompt = false;
                                                    root.showEnterprisePrompt = false;
                                                }
                                                return;
                                            }
                                            // Left-click: original behavior
                                            root.showDetailPanel = false;
                                            root.detailPanelSsid = "";
                                            if (modelData.connected) {
                                                network.disconnectNetwork(modelData.ssid);
                                            } else if (network.isEnterprise(modelData.security) && !modelData.existing) {
                                                root.showEnterprisePrompt = true;
                                                root.enterprisePromptSsid = modelData.ssid;
                                                root.enterpriseIdentity = "";
                                                root.enterpriseEapMethod = "peap";
                                                root.enterprisePhase2Auth = "mschapv2";
                                                root.enterpriseCaCert = "";
                                                root.enterpriseClientCert = "";
                                                root.enterprisePrivateKey = "";
                                                root.enterprisePrivateKeyPassword = "";
                                                root.enterpriseAnonymousIdentity = "";
                                                root.enterpriseDomainSuffixMatch = "";
                                                passwordPromptSsid = "";
                                                showPasswordPrompt = false;
                                            } else if (network.needsPassword(modelData.security) && !modelData.existing) {
                                                passwordPromptSsid = modelData.ssid;
                                                showPasswordPrompt = true;
                                                passwordInput = "";
                                                root.showEnterprisePrompt = false;
                                                Qt.callLater(function() {
                                                    passwordInputField.forceActiveFocus();
                                                });
                                            } else {
                                                network.connectNetwork(modelData.ssid, modelData.security);
                                            }
                                        }
                                    }
                                }

                                // Password prompt section
                                Rectangle {
                                    id: passwordPromptSection
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: modelData.ssid === passwordPromptSsid && showPasswordPrompt ? 60 : 0
                                    Layout.margins: 8
                                    visible: modelData.ssid === passwordPromptSsid && showPasswordPrompt
                                    color: Theme.surfaceVariant
                                    radius: 8

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                color: "transparent"
                                                border.color: passwordInputField.activeFocus ? Theme.accentPrimary : Theme.outline
                                                border.width: 1

                                                TextInput {
                                                    id: passwordInputField
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    text: passwordInput
                                                    font.pixelSize: 13 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    focus: true
                                                    selectByMouse: true
                                                    activeFocusOnTab: true
                                                    inputMethodHints: Qt.ImhNone
                                                    echoMode: TextInput.Password
                                                    onTextChanged: passwordInput = text
                                                    onAccepted: {
                                                        network.submitPassword(passwordPromptSsid, passwordInput);
                                                        showPasswordPrompt = false;
                                                    }

                                                    MouseArea {
                                                        id: passwordInputMouseArea
                                                        anchors.fill: parent
                                                        onClicked: passwordInputField.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 36
                                            radius: 18
                                            color: Theme.accentPrimary
                                            border.color: Theme.accentPrimary
                                            border.width: 0
                                            opacity: 1.0

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 100
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    network.submitPassword(passwordPromptSsid, passwordInput);
                                                    showPasswordPrompt = false;
                                                }
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onEntered: parent.color = Qt.darker(Theme.accentPrimary, 1.1)
                                                onExited: parent.color = Theme.accentPrimary
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Connect"
                                                color: Theme.backgroundPrimary
                                                font.pixelSize: 14 * Theme.scale(Screen)
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                // Connection detail/info panel (right-click)
                                Rectangle {
                                    id: detailPanel
                                    property bool isVisible: modelData.ssid === root.detailPanelSsid && root.showDetailPanel
                                    visible: isVisible
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: isVisible ? barDetailPanelContent.implicitHeight + 20 : 0
                                    Layout.margins: 8
                                    radius: 10
                                    color: Theme.surfaceVariant
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: 1
                                    opacity: isVisible ? 1.0 : 0.0
                                    clip: true

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    // Reset confirmForget when panel visibility changes
                                    onIsVisibleChanged: {
                                        if (!isVisible) {
                                            forgetButtonRow.confirmForget = false;
                                        }
                                    }

                                    ColumnLayout {
                                        id: barDetailPanelContent
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        // Header
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: "info"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 18 * Theme.scale(Screen)
                                                color: Theme.accentPrimary
                                            }
                                            Text {
                                                text: modelData.ssid
                                                font.pixelSize: 14 * Theme.scale(Screen)
                                                font.bold: true
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Rectangle {
                                                width: 24; height: 24; radius: 12
                                                color: barDetailCloseArea.containsMouse ? Theme.highlight : "transparent"
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "close"
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 14 * Theme.scale(Screen)
                                                    color: Theme.textSecondary
                                                }
                                                MouseArea {
                                                    id: barDetailCloseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.showDetailPanel = false;
                                                        root.detailPanelSsid = "";
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.12 }

                                        // Loading
                                        Spinner {
                                            visible: network.detailsLoading
                                            running: network.detailsLoading
                                            color: Theme.accentPrimary
                                            size: 18
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        // Error message
                                        Text {
                                            visible: !network.detailsLoading && network.detailError.length > 0
                                            text: network.detailError
                                            color: Theme.error
                                            font.pixelSize: 10 * Theme.scale(Screen)
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }

                                        // Status row with signal badge
                                        RowLayout {
                                            visible: !network.detailsLoading
                                            Layout.fillWidth: true
                                            spacing: 12

                                            RowLayout {
                                                spacing: 4
                                                Text {
                                                    text: modelData.connected ? "link" : (modelData.existing ? "bookmark" : "wifi_find")
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 14 * Theme.scale(Screen)
                                                    color: modelData.connected ? "#43a047" : Theme.textSecondary
                                                }
                                                Text {
                                                    text: modelData.connected ? "Connected" : (modelData.existing ? "Saved" : "Available")
                                                    font.pixelSize: 11 * Theme.scale(Screen)
                                                    font.bold: true
                                                    color: modelData.connected ? "#43a047" : Theme.textSecondary
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Signal & Security badges
                                            RowLayout {
                                                spacing: 6
                                                Rectangle {
                                                    Layout.preferredHeight: 20
                                                    Layout.preferredWidth: signalBadgeRow.implicitWidth + 12
                                                    radius: 10
                                                    color: Qt.rgba(Theme.accentPrimary.r, Theme.accentPrimary.g, Theme.accentPrimary.b, 0.12)
                                                    RowLayout {
                                                        id: signalBadgeRow
                                                        anchors.centerIn: parent
                                                        spacing: 3
                                                        Text {
                                                            text: network.signalIcon(modelData.signal)
                                                            font.family: "Material Symbols Outlined"
                                                            font.pixelSize: 12 * Theme.scale(Screen)
                                                            color: Theme.accentPrimary
                                                        }
                                                        Text {
                                                            text: modelData.signal + "%"
                                                            font.pixelSize: 10 * Theme.scale(Screen)
                                                            font.bold: true
                                                            color: Theme.accentPrimary
                                                        }
                                                    }
                                                }
                                                Rectangle {
                                                    Layout.preferredHeight: 20
                                                    Layout.preferredWidth: secBadgeText.implicitWidth + 12
                                                    radius: 10
                                                    color: Qt.rgba(Theme.textSecondary.r, Theme.textSecondary.g, Theme.textSecondary.b, 0.12)
                                                    Text {
                                                        id: secBadgeText
                                                        anchors.centerIn: parent
                                                        text: modelData.security && modelData.security !== "--" ? modelData.security : "Open"
                                                        font.pixelSize: 10 * Theme.scale(Screen)
                                                        color: Theme.textSecondary
                                                    }
                                                }
                                            }
                                        }

                                        // Auto-connect toggle
                                        RowLayout {
                                            visible: !network.detailsLoading && modelData.existing
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: "autorenew"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 14 * Theme.scale(Screen)
                                                color: Theme.textSecondary
                                            }
                                            Text {
                                                text: "Auto-connect"
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                Layout.fillWidth: true
                                            }
                                            Rectangle {
                                                id: autoConnectSwitch
                                                property bool checked: {
                                                    if (!network.connectionDetails) return true;
                                                    var val = network.connectionDetails["connection.autoconnect"];
                                                    return val !== "no";
                                                }
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 20
                                                radius: 10
                                                color: checked ? Theme.accentPrimary : Qt.rgba(Theme.textSecondary.r, Theme.textSecondary.g, Theme.textSecondary.b, 0.3)
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                Rectangle {
                                                    width: 16; height: 16; radius: 8
                                                    x: autoConnectSwitch.checked ? parent.width - width - 2 : 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: Theme.backgroundPrimary
                                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        network.setAutoConnect(modelData.ssid, !autoConnectSwitch.checked);
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle { visible: !network.detailsLoading; Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.08 }

                                        // Detail rows (use constant keyMap/order from Network, skip autoconnect as it has its own toggle)
                                        Repeater {
                                            model: {
                                                if (network.detailsLoading || !network.connectionDetails)
                                                    return [];
                                                var items = [];
                                                var d = network.connectionDetails;
                                                for (var i = 0; i < network.detailKeyOrder.length; ++i) {
                                                    var k = network.detailKeyOrder[i];
                                                    if (k === "connection.autoconnect") continue; // shown as toggle above
                                                    if (d[k])
                                                        items.push({ label: network.detailKeyMap[k], value: d[k] });
                                                }
                                                return items;
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    text: modelData.label
                                                    font.pixelSize: 10 * Theme.scale(Screen)
                                                    color: Theme.textSecondary
                                                    Layout.preferredWidth: 72
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                                Text {
                                                    text: modelData.value
                                                    font.pixelSize: 10 * Theme.scale(Screen)
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WrapAnywhere
                                                }
                                            }
                                        }

                                        // Forget button with confirmation
                                        RowLayout {
                                            id: forgetButtonRow
                                            visible: !network.detailsLoading && modelData.existing
                                            Layout.fillWidth: true
                                            Layout.topMargin: 4
                                            spacing: 8
                                            property bool confirmForget: false
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                Layout.preferredWidth: forgetBtnText.implicitWidth + 24
                                                Layout.preferredHeight: 26
                                                radius: 13
                                                color: barForgetBtnArea.containsMouse ? Theme.error : "transparent"
                                                border.color: Theme.error
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                                Text {
                                                    id: forgetBtnText
                                                    anchors.centerIn: parent
                                                    text: forgetButtonRow.confirmForget ? "Confirm?" : "Forget"
                                                    font.pixelSize: 10 * Theme.scale(Screen)
                                                    font.bold: true
                                                    color: barForgetBtnArea.containsMouse ? Theme.backgroundPrimary : Theme.error
                                                }
                                                MouseArea {
                                                    id: barForgetBtnArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (!forgetButtonRow.confirmForget) {
                                                            forgetButtonRow.confirmForget = true;
                                                            return;
                                                        }
                                                        network.forgetNetwork(modelData.ssid);
                                                        root.showDetailPanel = false;
                                                        root.detailPanelSsid = "";
                                                    }
                                                }
                                            }
                                        }

                                        // Forget error feedback
                                        Text {
                                            visible: network.forgetError.length > 0
                                            text: network.forgetError
                                            color: Theme.error
                                            font.pixelSize: 10 * Theme.scale(Screen)
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Enterprise (802.1X) authentication form
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: modelData.ssid === root.enterprisePromptSsid && root.showEnterprisePrompt ? barEnterpriseFormContent.implicitHeight + 24 : 0
                                    Layout.margins: 8
                                    visible: modelData.ssid === root.enterprisePromptSsid && root.showEnterprisePrompt
                                    color: Theme.surfaceVariant
                                    radius: 8
                                    clip: true
                                    ColumnLayout {
                                        id: barEnterpriseFormContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 6

                                        // EAP Method selector
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text {
                                                text: "EAP:"
                                                font.pixelSize: 11 * Theme.scale(Screen)
                                                color: Theme.textSecondary
                                                Layout.preferredWidth: 36
                                            }
                                            Repeater {
                                                model: ["peap", "ttls", "tls"]
                                                Rectangle {
                                                    Layout.preferredWidth: 44
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: root.enterpriseEapMethod === modelData ? Theme.accentPrimary : "transparent"
                                                    border.color: Theme.accentPrimary
                                                    border.width: 1
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.toUpperCase()
                                                        font.pixelSize: 9 * Theme.scale(Screen)
                                                        font.bold: true
                                                        color: root.enterpriseEapMethod === modelData ? Theme.backgroundPrimary : Theme.accentPrimary
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.enterpriseEapMethod = modelData
                                                    }
                                                }
                                            }
                                        }

                                        // Identity field
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barEnterpriseIdentityField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barEnterpriseIdentityField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                property string placeholderText: "Username / Identity"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterpriseIdentity = text
                                            }
                                        }

                                        // Password field
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barEnterprisePasswordField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barEnterprisePasswordField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                echoMode: TextInput.Password
                                                property string placeholderText: root.enterpriseEapMethod === "tls" ? "Password (optional)" : "Password"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onAccepted: barEnterpriseConnectBtn.doConnect()
                                            }
                                        }

                                        // --- Certificate fields (common to all EAP methods) ---

                                        // CA Certificate path
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barCaCertField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barCaCertField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                property string placeholderText: "CA Certificate (optional)"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterpriseCaCert = text
                                            }
                                        }

                                        // Anonymous Identity
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barAnonIdentityField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barAnonIdentityField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                property string placeholderText: "Anonymous Identity (optional)"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterpriseAnonymousIdentity = text
                                            }
                                        }

                                        // Domain Suffix Match
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barDomainMatchField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barDomainMatchField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                property string placeholderText: "Domain Suffix Match (optional)"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterpriseDomainSuffixMatch = text
                                            }
                                        }

                                        // --- TLS-only fields ---

                                        // Client Certificate path (TLS only)
                                        Rectangle {
                                            visible: root.enterpriseEapMethod === "tls"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barClientCertField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barClientCertField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                property string placeholderText: "Client Certificate"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterpriseClientCert = text
                                            }
                                        }

                                        // Private Key path (TLS only)
                                        Rectangle {
                                            visible: root.enterpriseEapMethod === "tls"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barPrivateKeyField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barPrivateKeyField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                property string placeholderText: "Private Key"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterprisePrivateKey = text
                                            }
                                        }

                                        // Private Key Password (TLS only)
                                        Rectangle {
                                            visible: root.enterpriseEapMethod === "tls"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: "transparent"
                                            border.color: barPrivateKeyPwdField.activeFocus ? Theme.accentPrimary : Theme.outline
                                            border.width: 1
                                            TextInput {
                                                id: barPrivateKeyPwdField
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                color: Theme.textPrimary
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                selectByMouse: true
                                                activeFocusOnTab: true
                                                echoMode: TextInput.Password
                                                property string placeholderText: "Private Key Password"
                                                Text {
                                                    visible: !parent.text
                                                    text: parent.placeholderText
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 12 * Theme.scale(Screen)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                onTextChanged: root.enterprisePrivateKeyPassword = text
                                            }
                                        }

                                        // Connect button
                                        Rectangle {
                                            id: barEnterpriseConnectBtn
                                            Layout.alignment: Qt.AlignRight
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 30
                                            radius: 15
                                            color: Theme.accentPrimary
                                            Behavior on color {
                                                ColorAnimation { duration: 100 }
                                            }

                                            function doConnect() {
                                                network.submitEnterprise(
                                                    modelData.ssid,
                                                    barEnterpriseIdentityField.text,
                                                    barEnterprisePasswordField.text,
                                                    root.enterpriseEapMethod,
                                                    root.enterprisePhase2Auth,
                                                    {
                                                        caCert: root.enterpriseCaCert,
                                                        clientCert: root.enterpriseClientCert,
                                                        privateKey: root.enterprisePrivateKey,
                                                        privateKeyPassword: root.enterprisePrivateKeyPassword,
                                                        anonymousIdentity: root.enterpriseAnonymousIdentity,
                                                        domainSuffixMatch: root.enterpriseDomainSuffixMatch
                                                    }
                                                );
                                                root.showEnterprisePrompt = false;
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onEntered: parent.color = Qt.darker(Theme.accentPrimary, 1.1)
                                                onExited: parent.color = Theme.accentPrimary
                                                onClicked: barEnterpriseConnectBtn.doConnect()
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Connect"
                                                color: Theme.backgroundPrimary
                                                font.pixelSize: 12 * Theme.scale(Screen)
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}