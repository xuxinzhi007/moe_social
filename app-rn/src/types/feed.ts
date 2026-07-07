export interface TopicTag {
  id: string;
  name: string;
  color?: string;
}

export interface FeedPost {
  id: string;
  userId: string;
  userName: string;
  userAvatar: string;
  content: string;
  images: string[];
  topicTags: TopicTag[];
  likes: number;
  comments: number;
  isLiked: boolean;
  createdAt: string;
  hasHandDraw: boolean;
  authorIsBot: boolean;
}

export interface FeedListResult {
  posts: FeedPost[];
  total: number;
}
