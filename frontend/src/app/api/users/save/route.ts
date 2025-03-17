import { CHAIN, PUBLIC_CLIENT, transport } from "@/constants";
import { FACTORY_ABI } from "@/constants/factory";
import { Hex, createWalletClient, toHex, zeroAddress } from "viem";
import { privateKeyToAccount } from "viem/accounts";

export async function POST(req: Request) {
  const { id, pubKey } = (await req.json()) as { id: Hex; pubKey: [Hex, Hex] };

  const account = privateKeyToAccount(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  );
  const walletClient = createWalletClient({
    account,
    chain: CHAIN,
    transport,
  });

  const user = await PUBLIC_CLIENT.readContract({
    address: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    abi: FACTORY_ABI,
    functionName: "getUser",
    args: [BigInt(id)],
  });

  if (user.account !== zeroAddress) {
    return Response.json(undefined);
  }

  await walletClient.writeContract({
    address: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    abi: FACTORY_ABI,
    functionName: "saveUser",
    args: [BigInt(id), pubKey],
  });

  const smartWalletAddress = await PUBLIC_CLIENT.readContract({
    address: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    abi: FACTORY_ABI,
    functionName: "getAddress",
    args: [pubKey],
  });

  // await walletClient.sendTransaction({
  //   to: smartWalletAddress,
  //   value: BigInt(1),
  // });

  const createdUser = {
    id,
    account: smartWalletAddress,
    pubKey,
  };

  return Response.json(createdUser);
}
