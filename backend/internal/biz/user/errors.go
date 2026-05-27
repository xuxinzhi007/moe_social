package userbiz

import "errors"

var (
	ErrNotFound        = errors.New("user not found")
	ErrInvalidArgument = errors.New("invalid argument")
	ErrUnauthorized    = errors.New("unauthorized")
	ErrAlreadyExists   = errors.New("already exists")
)
