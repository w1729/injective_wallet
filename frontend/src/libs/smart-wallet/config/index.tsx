import { fallback, http } from "viem";

// const publicRpc = http("https://goerli.base.org");
// const localhost = http("http://localhost:8545");
const stackUpBundlerRpcUrl = http(`http://localhost:4338/rpc`);

export const transport = stackUpBundlerRpcUrl;
