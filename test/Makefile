test: info clean helloworld
	@test -f helloworld.exe && file helloworld.exe ; \
	test -f helloworld.exe || file helloworld

info:
	@echo "------------------------------------------------------------------------"
	@echo CROSS_TRIPLE: $(CROSS_TRIPLE)

clean:
	@rm -f helloworld helloworld.exe
