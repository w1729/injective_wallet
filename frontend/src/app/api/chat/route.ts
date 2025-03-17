import { togetherai } from "@ai-sdk/togetherai";
import { streamText } from "ai";
import { tools } from "../../../ai/tools";
export const maxDuration = 30;

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: togetherai("meta-llama/Llama-3.3-70B-Instruct-Turbo"),
    system:
      "You are a highly knowledgeable and efficient Injective blockchain assistant, designed to help users with anything related to Injective. You provide expert guidance on DeFi, NFTs, on-chain derivatives, MEV, account abstraction, and more. Your responses are clear, concise, and actionable, ensuring users can easily understand and apply your insights.",
    messages,
    tools,
  });

  return result.toDataStreamResponse();
}
