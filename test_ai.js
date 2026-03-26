
const apiKey = 'ccbb63159e1147698a671b050161f27f.RCHbtYIzVw88HzVuP7AVXKiE';
const apiUrl = 'https://ollama.com/api/chat';
const model = 'qwen3.5';

async function testCloudAI() {
  console.log('Testing Ollama Cloud API...');
  console.log('URL:', apiUrl);
  console.log('Model:', model);

  try {
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: model,
        stream: false,
        messages: [{ role: 'user', content: 'Say hello' }]
      })
    });

    console.log('Status:', response.status);
    const text = await response.text();
    console.log('Response body:', text);

    if (response.ok) {
      try {
        const data = JSON.parse(text);
        console.log('Parsed Answer:', data.message?.content || data.choices?.[0]?.message?.content);
      } catch (e) {
        console.log('Failed to parse JSON response');
      }
    }
  } catch (err) {
    console.error('Fetch Error:', err.message);
  }
}

testCloudAI();
