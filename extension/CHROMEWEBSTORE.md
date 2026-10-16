# Chrome Web Store Listing: LazyType Mac Remote Bridge

## Metadata
- **Name**: LazyType Mac Remote Bridge
- **Version**: 1.0.0
- **Summary**: Type and send chat messages during meetings on your Mac directly from your phone.
- **Category**: Productivity

## Detailed Description
LazyType allows you to participate in video calls and chats on your computer while comfortably leaning back, typing your thoughts on your phone.

When you send a message from your phone, LazyType locates the meeting window, focuses the chat input field, enters your message, and delivers it instantly—without any coordinate-based mouse jumping.

### Key Features:
- Seamless typing directly into Google Meet, Zoom Web, and video conferencing chat boxes.
- Direct interaction with web form controls and content-editable areas.
- Audio mute and camera toggling from your phone.
- Automatic detection of active meeting sessions.

## Permissions Justification
- `tabs`: Required to detect whether an active meeting tab (such as Google Meet or Zoom) is open so remote messages can be directed to the right meeting.
- `storage`: Stores local user settings and connection preferences for connecting to the local Mac companion.
- `alarms`: Periodically ensures background communication with the local Mac companion remains active.
- `host_permissions` (`*://meet.google.com/*`, `*://*.zoom.us/*`, `http://127.0.0.1/*`, `http://localhost/*`): Required to inject text and interact with chat elements inside active meeting web interfaces on behalf of the user.

## Privacy & Data Use
- **Single purpose**: Remote typing companion for meeting chats.
- **Data collection**: No personal data, chat messages, or browsing activity are transmitted to any cloud servers. All communications are strictly local between your Mac and phone on your own Wi-Fi network.
