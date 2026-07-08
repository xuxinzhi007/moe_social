package lifehttp

import "github.com/go-kratos/kratos/v2/errors"

var errLifeAppNil = errors.ServiceUnavailable("LIFE_APP", "life app service not configured")
