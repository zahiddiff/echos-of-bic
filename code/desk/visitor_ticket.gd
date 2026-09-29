extends Node
class_name VisitorTicket

## A visitor's paperwork as a Node.

var request: VisitorRequest

static func of(new_request: VisitorRequest) -> VisitorTicket:
	var ticket := VisitorTicket.new()
	ticket.request = new_request
	ticket.name = "Ticket"
	return ticket
