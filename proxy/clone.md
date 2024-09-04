https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args/blob/main/src/ClonesWithImmutableArgs.sol
实际上创建了一个合约，该合约的代码段按照[runtime](https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args/blob/105efee1b9127ed7f6fedf139e1fc796ce8791f2/src/ClonesWithImmutableArgs.sol#L47C16-L47C24)去拼接，里面的代码段按照如下方式去拼接。
```
// --- copy calldata to memmory ---
// opcode      |  name                 | stack包含的内容          | memory内容
// 36          | CALLDATASIZE          | cds                     | –
// 3d          | RETURNDATASIZE        | 0 cds                   | –
// 3d          | RETURNDATASIZE        | 0 0 cds                 | –
// 37          | CALLDATACOPY          |                         | [0 - cds): calldata
```
最终会执行这段代码，即先把calldata准备好，再[delegate call](https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args/blob/105efee1b9127ed7f6fedf139e1fc796ce8791f2/src/ClonesWithImmutableArgs.sol#L75)调用implementation合约地址
