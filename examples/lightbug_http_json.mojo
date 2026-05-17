# Source: https://github.com/saviorand/lightbug_http/blob/04d303e6515ee6f35ca36643b8e1a879f54738cb/lightbug_http/http/json.mojo
# License: MIT — see https://github.com/saviorand/lightbug_http/blob/04d303e6515ee6f35ca36643b8e1a879f54738cb/LICENSE
# Copied verbatim for tree-sitter-mojo acceptance corpus (issue #28).

from emberjson import (
    parse,
    deserialize,
    try_deserialize,
    serialize,
    Value,
    JsonSerializable,
    JsonDeserializable,
)
from lightbug_http.http.request import HTTPRequest


struct Json:
    """Pre-serialized JSON value for use as an HTTP response body."""

    var _serialized: String

    fn __init__[T: AnyType](out self, value: T):
        self._serialized = serialize(value)


fn json_decode(req: HTTPRequest) raises -> Value:
    """Parse the request body as untyped JSON.

    Args:
        req: The HTTP request to extract JSON from.

    Returns:
        A parsed JSON value.

    Raises:
        An error if the body is not valid JSON.
    """
    return parse(req.get_body())


fn json_decode[T: Movable & ImplicitlyDestructible](req: HTTPRequest) raises -> T:
    """Deserialize the request body into a typed struct.

    Parameters:
        T: Any struct conforming to Movable & ImplicitlyDestructible. Types with
           fields that have non-trivial destructors must also conform to Defaultable.

    Args:
        req: The HTTP request to deserialize JSON from.

    Returns:
        The deserialized value.

    Raises:
        An error if the body is not valid JSON or doesn't match the expected schema.
    """
    return deserialize[T](String(req.get_body()))
