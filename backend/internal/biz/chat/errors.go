package chatbiz

import "errors"

var (
	ErrChatStoreUnavailable = errors.New("chat store unavailable")
	ErrInvalidSenderID      = errors.New("invalid sender id")
	ErrInvalidReceiverID    = errors.New("invalid receiver id")
	ErrInvalidViewerID      = errors.New("invalid viewer id")
	ErrInvalidPeerID        = errors.New("invalid peer id")
	ErrInvalidBeforeID      = errors.New("invalid before id")
	ErrMessageSelf          = errors.New("cannot message self")
	ErrEmptyMessageBody     = errors.New("empty message body")
	ErrMessageBodyTooLong   = errors.New("message body too long")
	ErrTooManyImagePaths    = errors.New("too many image paths")
	ErrInvalidImagePath     = errors.New("invalid image path")
	ErrUserNotFound         = errors.New("chat user not found")
	ErrPeerNotFound         = errors.New("chat peer not found")
	ErrSaveMessage          = errors.New("save private message failed")
	ErrQueryMessages        = errors.New("query private messages failed")
)
