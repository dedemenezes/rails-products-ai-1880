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

  def nearest_products
    response = client.embeddings(
      parameters: {
        model: 'text-embedding-3-small',
        input: @question.user_question
      }
    )
    question_embedding = response['data'][0]['embedding']
    return Product.nearest_neighbors(
      :embedding, question_embedding,
      distance: "euclidean"
    ) # you may want to add .first(3) here to limit the number of results
  end

  # we need to send ALL THE QUESTIONS EVERY SINGLE TIME TO GPT
  def questions_formatted_for_openai
    questions = @question.user.questions
    results = []
    system_text = "You are an assistant for an e-commerce website. 1. Always say the name of the product. 2. If you don't know the answer, you can say 'I don't know. If you don't have any products at the end of this message, say we don't have that.  Here are the products you should use to answer the user's questions: "
    # to nearest_products code as private method
    nearest_products.each do |product|
      system_text += "** PRODUCT #{product.id}: name: #{product.name}, description: #{product.description} **"
    end
    results << { role: "system", content: system_text }

    # results << { role: "system", content: "You are an assistant for an e-commerce website." }

    questions.each do |question|
      results << { role: "user", content: question.user_question }
      results << { role: "assistant", content: question.ai_answer || '' }
    end

    return results
  end
end
