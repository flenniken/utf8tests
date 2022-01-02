## OpResult holds either a value or a message.  It's similar to
## @:the Option type but instead of returning nothing, you return a
## @:message that tells why you cannot return the value.
## @:
## @:Example Usage:
## @:
## @:~~~
## @:proc test(): OpResult[int, string] =
## @:  if problem:
## @:    result = newOpResultMsg@{int, string}@("unable to do the task")
## @:  else:
## @:    result = newOpResult@{int, string}@(3)
## @:
## @:let numOr = test()
## @:if numOr.isMessage():
## @:  echo numOr.message
## @:else:
## @:  num = numOr.value
## @:~~~~

type
  OpResultKind = enum
    ## The kind of OpResult object, either a message or a value.
    orMessage,
    orValue

  OpResult*[T, T2] = object
    ## Contains either a value or a message. Defaults to an empty
    ## message.
    case kind*: OpResultKind
      of orValue:
        value*: T
      of orMessage:
        message*: T2

func isMessage*(opResult: OpResult): bool =
  ## Return true when the OpResult object contains a message.
  if opResult.kind == orMessage:
    result = true

func isValue*(opResult: OpResult): bool =
  ## Return true when the OpResult object contains a value.
  if opResult.kind == orValue:
    result = true

func newOpResult*[T, T2](value: T): OpResult[T, T2] =
  ## Create an OpResult value object.
  return OpResult[T, T2](kind: orValue, value: value)

func newOpResultMsg*[T, T2](message: T2): OpResult[T, T2] =
  ## Create an OpResult message object.
  return OpResult[T, T2](kind: orMessage, message: message)

func `$`*(optionRc: OpResult): string =
  ## Return a string representation of an OpResult object.
  if optionRc.kind == orValue:
    result = "Value: " & $optionRc.value
  else:
    result = "Message: " & $optionRc.message
