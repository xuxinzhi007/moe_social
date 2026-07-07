export interface ChatMessage {
  id: string;
  senderId: string;
  receiverId: string;
  body: string;
  imagePaths: string[];
  createdAt: string;
  senderMoeNo?: string;
  receiverMoeNo?: string;
}

export interface ChatConversation {
  peerId: string;
  peerName: string;
  peerAvatar: string;
  peerMoeNo?: string;
  peerDisplayUserId?: string;
  unreadCount: number;
  lastMessage?: ChatMessage;
}
