class ChatbotJob < ApplicationJob
  queue_as :default

  def perform(question)
    @question = question
    # we need to send our question to the OpenAI
    # 1. create the OPEN AI client
    # 2. Send the question using the open ai client
    chatgpt_response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: questions_formatted_for_openai  # to code as private method
      }
    )
    # get the answer from the AI
    ai_answer = chatgpt_response["choices"][0]['message']['content']

    # update the question to store the answe
    question.update(ai_answer: ai_answer  )
    # system    - allow us to configure the GPT behavior
    # assistant - is the GPT response
    # user      - the messages WE sent to GPT

    # we need to append the answer into the page
    Turbo::StreamsChannel.broadcast_update_to(
      "question_#{@question.id}",
      target: "question_#{@question.id}",
      partial: "questions/question", locals: { question: question })

  end

  private

  def client
    @client ||= OpenAI::Client.new
  end

  # we need to send ALL THE QUESTIONS EVERY SINGLE TIME TO GPT
  def questions_formatted_for_openai
    results = []

    questions = @question.user.questions
    results << { role: "system", content: "You are an assistant for an e-commerce website." }
    questions.each do |question|
      results << { role: "user", content: question.user_question }
      results << { role: "assistant", content: question.ai_answer || '' }
    end

    return results
  end
end
