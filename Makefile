NAME=.chain
DIR=~/$(NAME)
GENESIS=genesis.json

.PHONY=init mine

init:
	geth --identity $(NAME) --nodiscover --networkid 1999 --datadir $(DIR) init $(GENESIS)
	geth account new --datadir $(DIR)

mine:
	geth --identity $(NAME) --nodiscover --networkid 1999 --datadir $(DIR) mine
