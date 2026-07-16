import { CategoryScoreUpdated } from "../generated/ContextualReputation/ContextualReputation";
import { CategoryScore } from "../generated/schema";

export function handleCategoryScoreUpdated(event: CategoryScoreUpdated): void {
  const id = event.params.agentId.toString() + "-" + event.params.category.toString();
  let score = CategoryScore.load(id);
  if (score == null) {
    score = new CategoryScore(id);
    score.agentId = event.params.agentId;
    score.category = event.params.category.toI32();
  }
  score.score = event.params.newScore;
  score.tasksCompleted = event.params.tasksCompleted;
  score.updatedAt = event.block.timestamp;
  score.save();
}
