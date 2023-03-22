Extension { #name : #RBCodeSnippetTest }

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testCompile [

	| method |

	self skipIf: #compile.
	method := snippet compile.
	self assert: method isCompiledMethod.

	snippet isFaulty
		ifTrue: [
			| ast |
			self assert: method hasSourceCode.
			self assert: method sourceCode equals: snippet source.
			ast := method propertyAt: #ast.
			self assert: ast isFaulty.

			"Some faulty AST can produce non faulty method where no `signalSyntaxError:` is present"
			self assert: method isFaulty equals: snippet hasValue not]
		ifFalse: [
			self deny: method isFaulty ].
	self testExecute: method
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testCompileOnError [

	| method error |
	error := nil.
	method := snippet compileOnError: [ :e | error := e messageText ].
	snippet isFaulty
		ifTrue: [ self assert: error isNotNil ]
		ifFalse: [
			self assert: error isNil.
			self assert: method isCompiledMethod.
			self testExecute: method ]
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testCompileOnErrorResume [

	| method error |
	error := nil.
	method := snippet compileOnError: [ :e | error := e messageText. e resume ].
	self assert: snippet isFaulty equals: error isNotNil.
	self assert: method isCompiledMethod.
	self testExecute: method
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testCompileWithRequestor [

	| requestor method |
	requestor := OCMockRequestor new.
	requestor interactive: false.
	requestor isScripting: nil.
	requestor text: nil.
	method := OpalCompiler new
		          noPattern: snippet isMethod not;
		          requestor: requestor;
		          failBlock: [ "When a requestion is set, a failBlock MUST also be set or compilation might crash internally"
			          self assert: requestor notifyList isNotEmpty.
			          self assert: snippet isFaulty.
			          ^ self ];
		          compile: snippet source.

	"Still alive? (failBlock never called)"
	self deny: snippet isFaulty.
	self assert: requestor notifyList isEmpty.
	self assert: method isCompiledMethod.
	self testExecute: method
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testDecompile [

	| method ast |
	method := snippet compile.
	method ifNil: [ ^ self skip ]. "Another test responsibility"
	ast := method decompile.
	self assert: ast isMethod.
	ast := method parseTree.
	self assert: ast isMethod.
	"Decompilation lose many information. Not sure how to test more"
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testDecompileIR [

	| method ir |
	method := snippet compile.
	method ifNil: [ ^ self skip ]. "Another test responsibility"
	ir := method decompileIR.
	self assert: ir class equals: IRMethod.
	"Decompilation lose information. Not sure how to test more"
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testDoSemanticAnalysis [
	"We should test more than that"

	| ast |
	ast := snippet doSemanticAnalysis.
	self assert: ast isMethod.
	self assert: ast isFaulty equals: snippet isFaulty
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testDoSemanticAnalysisOnError [
	"We should test more than that"

	| ast error |
	error := nil.

	ast := snippet doSemanticAnalysisOnError: [ :e | error := e messageText ].

	snippet isFaulty
		ifTrue: [ self assert: error isNotNil ]
		ifFalse: [
			self deny: ast isFaulty.
			self assert: error isNil ]
]

{ #category : #'*OpalCompiler-Tests' }
RBCodeSnippetTest >> testExecute: method [

	| runBlock phonyArgs |
	self skipIf: #exec.
	self assert: method isCompiledMethod.

	phonyArgs := (1 to: method numArgs) asArray.

	"Executing a lone block will just return a block, we have to call value to have something more interesting"
	snippet parse isBlock
		ifTrue: [
			| block phonyBlockArgs |
			block := nil withArgs: phonyArgs executeMethod: method.
			phonyBlockArgs := (1 to: block numArgs) asArray.
			runBlock := [ block valueWithArguments: phonyBlockArgs ] ]
		ifFalse: [ runBlock := [ nil withArgs: phonyArgs executeMethod: method ] ].

	snippet messageNotUnderstood ifNotNil: [ :mnu |
		runBlock onDNU: mnu do: [ ^ self ].
		self signalFailure: 'Should have raised MNU ' , mnu ].

	snippet raise ifNotNil: [ :class | ^ self should: runBlock raise: class ].

	snippet hasValue
		ifFalse: [ self should: runBlock raise: RuntimeSyntaxError ]
		ifTrue: [ self assert: runBlock value equals: snippet value ]
]