import type { ApiEnvelope } from '../types/api';
import type { FeedListResult, FeedPost, TopicTag } from '../types/feed';

import { ApiClient } from './apiClient';

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {};
}

function asString(value: unknown) {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: unknown) {
  return typeof value === 'number' ? value : 0;
}

function asBoolean(value: unknown) {
  return typeof value === 'boolean' ? value : false;
}

function asStringArray(value: unknown) {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];
}

function mapTopicTag(value: unknown): TopicTag {
  const item = asRecord(value);
  return {
    id: asString(item.id),
    name: asString(item.name),
    color: asString(item.color),
  };
}

function mapPost(value: unknown): FeedPost {
  const item = asRecord(value);
  return {
    id: asString(item.id),
    userId: asString(item.user_id),
    userName: asString(item.user_name),
    userAvatar: asString(item.user_avatar),
    content: asString(item.content),
    images: asStringArray(item.images),
    topicTags: Array.isArray(item.topic_tags) ? item.topic_tags.map(mapTopicTag) : [],
    likes: asNumber(item.likes),
    comments: asNumber(item.comments),
    isLiked: asBoolean(item.is_liked),
    createdAt: asString(item.created_at),
    hasHandDraw: asBoolean(item.has_hand_draw),
    authorIsBot: asBoolean(item.author_is_bot),
  };
}

export async function getFeedPosts(
  client: ApiClient,
  viewerUserId?: string,
  page = 1,
  pageSize = 20,
): Promise<FeedListResult> {
  const response = await client.getWithQuery<ApiEnvelope>('/api/posts', {
    viewer_user_id: viewerUserId,
    page,
    page_size: pageSize,
  });
  const root = asRecord(response);
  const data = asRecord(root.data);
  const posts = Array.isArray(data.posts) ? data.posts : Array.isArray(root.posts) ? root.posts : [];
  const total = asNumber(data.total || root.total);

  return {
    posts: posts.map(mapPost),
    total,
  };
}

export async function likePost(
  client: ApiClient,
  postId: string,
  userId: string,
): Promise<FeedPost> {
  const response = await client.post<ApiEnvelope>(`/api/posts/${postId}/like`, {
    post_id: postId,
    user_id: userId,
  });
  const root = asRecord(response);
  const data = asRecord(root.data);
  const post = data.post ?? root.post;
  return mapPost(post);
}
