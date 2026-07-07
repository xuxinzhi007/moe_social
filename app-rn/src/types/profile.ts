export interface UserProfile {
  id: string;
  username: string;
  email: string;
  avatar: string;
  signature: string;
  gender: string;
  birthday: string;
  isVip: boolean;
  vipExpiresAt: string;
  balance: number;
  moeNo: string;
  displayUserId: string;
  giftCharm: number;
  receivedGiftValue: number;
  followers?: number;
  following?: number;
}
