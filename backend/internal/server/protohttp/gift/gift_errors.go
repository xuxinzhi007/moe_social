package gifthttp

import (
	"errors"

	giftbiz "backend/internal/biz/gift"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errGiftAppNil = status.Error(codes.FailedPrecondition, "GiftApp 未初始化")

func mapGiftError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, giftbiz.ErrInvalidUserID),
		errors.Is(err, giftbiz.ErrInvalidSenderID),
		errors.Is(err, giftbiz.ErrInvalidReceiverID),
		errors.Is(err, giftbiz.ErrInvalidGiftID),
		errors.Is(err, giftbiz.ErrEmptyGiftID),
		errors.Is(err, giftbiz.ErrInvalidGiftRequest):
		return status.Error(codes.InvalidArgument, err.Error())
	case errors.Is(err, giftbiz.ErrUserNotFound),
		errors.Is(err, giftbiz.ErrGiftNotFound):
		return status.Error(codes.NotFound, err.Error())
	case errors.Is(err, giftbiz.ErrInsufficientBal):
		return status.Error(codes.FailedPrecondition, "余额不足")
	default:
		return err
	}
}
