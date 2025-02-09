# Mudmouth

Mudmouth is a network diagnostic tool for capturing requests securely on iOS.

## Usage

- Capturing HTTP requests
- Capturing HTTPS requests with MitM
- Triggering workflows before and after capturing

## URL Schemes

### Add a Profile

```
mudmouth://add?name=<NAME>&url=<URL>[&direction=<DIRECTION>][&preAction=<ACTION>][&preActionUrlScheme=<URL>][&postAction=<ACTION>][&postActionUrlScheme=<URL>]
```

### Capture Requests

```
mudmouth://capture?name=<NAME>
```

### Parameters

| Parameter | Options                                           |
|-----------|---------------------------------------------------|
| ACTION    | 0: None (Default)<br>1: URL Scheme<br>2: Shortcut |
| DIRECTION | 0: Request<br>1: Request & Response (Default)     |

## On Completion

### URL Scheme

```
<URL>?requestHeaders=<REQUEST_HEADERS>&responseHeaders=<RESPONSE_HEADERS>
```

### Shortcut

```
shortcuts://run-shortcut?name=<NAME>&input=text&text={"requestHeaders":<REQUEST_HEADERS>,"responseHeaders":<RESPONSE_HEADERS>}
```

## License

Mudmouth is licensed under [the MIT License](/LICENSE).
