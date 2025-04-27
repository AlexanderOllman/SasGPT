document.addEventListener('DOMContentLoaded', () => {
    const chatForm = document.getElementById('chat-form');
    const userInput = document.getElementById('user-input');
    const chatMessages = document.getElementById('chat-messages');
    const citationList = document.getElementById('citation-list');
    const embeddingToggleDesktop = document.getElementById('embedding-toggle-desktop');
    const embeddingToggleMobile = document.getElementById('embedding-toggle-mobile');
    const desktopToggleOptions = document.querySelectorAll('.embedding-toggle.desktop-only .toggle-option');
    const mobileToggleOptions = document.querySelectorAll('.embedding-toggle.mobile-toggle .toggle-option');
    
    let chatHistory = [];
    let qaCitationHistory = []; // New array to store Q&A with citations
    let currentEmbeddingType = "openai"; // Default to OpenAI
    
    // Configure marked AFTER DOM content is loaded and hljs should be available
    if (typeof marked !== 'undefined' && typeof hljs !== 'undefined') {
        marked.setOptions({
            highlight: function(code, lang) {
                try {
                    // Explicitly check if language is supported, otherwise use auto-highlight
                    const language = hljs.getLanguage(lang) ? lang : 'plaintext';
                    return hljs.highlight(code, { language, ignoreIllegals: true }).value;
                } catch (e) {
                    console.error("Highlight.js error during highlight:", e);
                    return code; // Return original code on error
                }
            },
            breaks: true,
            gfm: true // Enable GitHub Flavored Markdown
        });
    } else {
        console.warn("Marked or Highlight.js not loaded correctly.");
        // Provide basic fallback if marked exists but hljs doesn't
        if (typeof marked !== 'undefined') {
             marked.setOptions({ breaks: true, gfm: true });
        }
    }
    
    // Fix iOS height issues with vh units
    function setMobileHeight() {
        const vh = window.innerHeight * 0.01;
        document.documentElement.style.setProperty('--vh', `${vh}px`);
    }
    
    // Initial call and on resize
    setMobileHeight();
    window.addEventListener('resize', setMobileHeight);
    
    // Function to show loading indicator
    function showLoading() {
        const loadingDiv = document.createElement('div');
        loadingDiv.className = 'loading';
        loadingDiv.innerHTML = `
            <div class="dot"></div>
            <div class="dot"></div>
            <div class="dot"></div>
        `;
        loadingDiv.id = 'loading-indicator';
        chatMessages.appendChild(loadingDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }
    
    // Function to remove loading indicator
    function removeLoading() {
        const loadingDiv = document.getElementById('loading-indicator');
        if (loadingDiv) {
            loadingDiv.remove();
        }
    }
    
    // Function to format the cost display
    function formatCost(cost) {
        if (!cost) return '';
        
        const totalCost = cost.total_cost;
        const embeddingCost = cost.embedding.cost;
        const chatInputCost = cost.chat.input_cost;
        const chatOutputCost = cost.chat.output_cost;
        
        let costString = `Total: $${totalCost.toFixed(6)}`;
        
        if (embeddingCost > 0) {
            costString += ` | Embedding: $${embeddingCost.toFixed(6)}`;
        }
        
        costString += ` | LLM: $${(chatInputCost + chatOutputCost).toFixed(6)}`;
        costString += ` (${cost.chat.input_tokens + cost.chat.output_tokens} tokens)`;
        
        return costString;
    }
    
    // Function to handle image loading and resize event for mobile
    function handleImagesLoad(messageEl) {
        const images = messageEl.querySelectorAll('img');
        let imagesLoaded = 0;
        
        if (images.length === 0) return;
        
        images.forEach(img => {
            if (img.complete) {
                imagesLoaded++;
                if (imagesLoaded === images.length) {
                    chatMessages.scrollTop = chatMessages.scrollHeight;
                }
            } else {
                img.addEventListener('load', () => {
                    imagesLoaded++;
                    if (imagesLoaded === images.length) {
                        chatMessages.scrollTop = chatMessages.scrollHeight;
                    }
                });
            }
            
            // Ensure images are responsive
            img.style.maxWidth = '100%';
            img.style.height = 'auto';
        });
    }
    
    // Function to add a message to the chat
    function addMessage(text, isUser = false, embeddingType = null, cost = null) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${isUser ? 'user-message' : 'bot-message'}`;
        
        // Create message content div
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        
        if (isUser) {
            // User messages are plain text
            contentDiv.textContent = text;
        } else {
            // Bot messages are rendered as Markdown
            contentDiv.innerHTML = marked.parse(text);
            
            // Add embedding type badge
            if (embeddingType) {
                const embeddingBadge = document.createElement('div');
                embeddingBadge.className = 'embedding-badge';
                embeddingBadge.textContent = embeddingType === 'tfidf' ? 'TF-IDF' : 'OpenAI';
                embeddingBadge.style.fontSize = '10px';
                embeddingBadge.style.color = '#94a3b8';
                embeddingBadge.style.marginTop = '5px';
                embeddingBadge.style.textAlign = 'right';
                contentDiv.appendChild(embeddingBadge);
            }
            
            // Add cost information if available
            if (cost) {
                const costInfo = document.createElement('div');
                costInfo.className = 'cost-info';
                costInfo.textContent = formatCost(cost);
                contentDiv.appendChild(costInfo);
            }
            
            // Handle images for proper scrolling
            handleImagesLoad(contentDiv);
        }
        
        messageDiv.appendChild(contentDiv);
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }
    
    // Function to process citations and add citation markers
    function processCitationsInText(text, citations) {
        let processedText = text;
        
        // Find citation markers like [citation1], [citation2], etc.
        // Also handle the format with or without curly braces: [citation{1}] or [citation1]
        const citationRegex = /\[citation\{?(\d+)\}?\]/g;
        
        // Replace each citation marker with a link
        processedText = processedText.replace(citationRegex, (match, citationNum) => {
            const citationNumber = citationNum;
            const citation = citations[parseInt(citationNumber) - 1];
            
            if (citation) {
                return `<a href="${citation.url}" class="citation-ref" data-citation-id="${citation.id}" target="_blank">[${citationNumber}]</a>`;
            }
            
            return match;
        });
        
        return processedText;
    }
    
    // New function to render citation history as dropdowns
    function renderCitationHistory(history) {
        citationList.innerHTML = ''; // Clear previous static content

        if (!history || history.length === 0) {
            const noCitationsDiv = document.createElement('div');
            noCitationsDiv.className = 'citation-item no-history'; // Add class for styling
            noCitationsDiv.textContent = 'Ask a question to see relevant citations.';
            citationList.appendChild(noCitationsDiv);
            return;
        }

        history.forEach((item, index) => {
            if (!item.citations || item.citations.length === 0) return; // Skip if no citations for this Q&A

            const detailsElement = document.createElement('details');
            detailsElement.className = 'citation-history-item';
            detailsElement.open = index === history.length - 1; // Open the last item by default

            const summaryElement = document.createElement('summary');
            // Use first ~10 words of the question as summary
            const summaryText = item.question.split(' ').slice(0, 10).join(' ') + (item.question.split(' ').length > 10 ? '...' : '');
            summaryElement.textContent = summaryText;
            detailsElement.appendChild(summaryElement);

            const citationsContainerDiv = document.createElement('div');
            citationsContainerDiv.className = 'citations-content';

            item.citations.forEach(citation => {
                const citationDiv = document.createElement('div');
                citationDiv.className = 'citation-item'; // Reuse existing class
                citationDiv.id = citation.id; // Keep ID for potential linking
                
                citationDiv.innerHTML = `
                    <div class="citation-page">Page ${citation.page}</div>
                    <div class="citation-text">${citation.text.substring(0, 150)}${citation.text.length > 150 ? '...' : ''}</div>
                    <a href="${citation.url}" class="citation-link" target="_blank">View in PDF</a>
                `;
                citationsContainerDiv.appendChild(citationDiv);
            });

            detailsElement.appendChild(citationsContainerDiv);
            citationList.appendChild(detailsElement);
        });
    }

    // Function to update the active state of toggle labels
    function updateToggleLabels(activeType) {
        desktopToggleOptions.forEach(opt => {
            opt.classList.toggle('active', opt.dataset.value === activeType);
        });
        mobileToggleOptions.forEach(opt => {
            opt.classList.toggle('active', opt.dataset.value === activeType);
        });
    }

    // Function to synchronize toggle states
    function syncToggles(sourceToggle) {
        const isChecked = sourceToggle.checked;
        if (embeddingToggleDesktop !== sourceToggle) embeddingToggleDesktop.checked = isChecked;
        if (embeddingToggleMobile !== sourceToggle) embeddingToggleMobile.checked = isChecked;
        // Update labels based on the new state
        updateToggleLabels(isChecked ? "openai" : "tfidf");
    }
    
    // Function to toggle embedding type via API
    async function updateEmbeddingType(sourceToggle) {
        const newType = sourceToggle.checked ? "openai" : "tfidf";
        syncToggles(sourceToggle); // Sync checkboxes and labels immediately
        
        // Prevent unnecessary API calls if type hasn't changed
        if (newType === currentEmbeddingType) return;

        try {
            // Show a message that we're switching
            const statusMessage = document.createElement('div');
            statusMessage.className = 'message bot-message';
            
            const messageContent = document.createElement('div');
            messageContent.className = 'message-content';
            messageContent.textContent = `Switching to ${newType === 'tfidf' ? 'TF-IDF' : 'OpenAI'} embeddings...`;
            
            statusMessage.appendChild(messageContent);
            statusMessage.id = 'status-message';
            chatMessages.appendChild(statusMessage);
            chatMessages.scrollTop = chatMessages.scrollHeight;
            
            // Call API to toggle embedding type
            const response = await fetch('/api/toggle_embeddings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    embedding_type: newType
                })
            });
            
            const data = await response.json();
            
            // Remove the status message
            const statusMsg = document.getElementById('status-message');
            if (statusMsg) {
                statusMsg.remove();
            }

            if (!response.ok || !data.success) {
                throw new Error(data.message || `Error switching: ${response.statusText}`);
            }
            
            // API call successful, update the official current type
            currentEmbeddingType = data.embedding_type;
            
            // Add confirmation message
            addMessage(data.message, false, data.embedding_type);
            
        } catch (error) {
            console.error('Error switching embedding types:', error);
            // Remove the status message
            const statusMsg = document.getElementById('status-message');
            if (statusMsg) {
                statusMsg.remove();
            }
            
            // Reset toggles and labels to the actual current state (before failed switch)
            embeddingToggleDesktop.checked = currentEmbeddingType === "openai";
            embeddingToggleMobile.checked = currentEmbeddingType === "openai";
            updateToggleLabels(currentEmbeddingType);
            
            // Add error message
            addMessage(`Error: ${error.message}`, false);
        }
    }
    
    // Function to handle form submission
    async function handleSubmit(e) {
        e.preventDefault();
        
        const message = userInput.value.trim();
        if (!message) return;
        
        // Add user message to chat
        addMessage(message, true);
        
        // Clear input field
        userInput.value = '';
        
        // Show loading indicator
        showLoading();
        
        try {
            // Send message to API
            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message,
                    history: chatHistory,
                    embedding_type: currentEmbeddingType
                })
            });
            
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.detail || `Error: ${response.statusText}`);
            }
            
            const data = await response.json();
            
            // Remove loading indicator
            removeLoading();
            
            // Process citations in the answer text
            const processedAnswer = processCitationsInText(data.answer, data.citations);
            
            // Add bot message with Markdown and citation links
            addMessage(processedAnswer, false, data.embedding_type, data.cost);
            
            // Store Q&A and citations together
            qaCitationHistory.push({
                question: message, 
                answer: data.answer, // Storing answer might be useful later
                citations: data.citations
            });

            // Render the updated citation history
            renderCitationHistory(qaCitationHistory);
            
            // Scroll to bottom
            chatMessages.scrollTop = chatMessages.scrollHeight;
            
            // Update chat history
            chatHistory.push({ 
                role: 'user', 
                content: message 
            });
            chatHistory.push({ 
                role: 'assistant', 
                content: data.answer 
            });
            
        } catch (error) {
            console.error('Error fetching chat response:', error);
            removeLoading();
            addMessage(`Sorry, there was an error processing your request: ${error.message}`, false);
        }
    }
    
    // Add event listener for embedding toggles
    // embeddingToggleDesktop.addEventListener('change', () => updateEmbeddingType(embeddingToggleDesktop));
    // embeddingToggleMobile.addEventListener('change', () => updateEmbeddingType(embeddingToggleMobile));
    
    // Add event listener for form submission
    chatForm.addEventListener('submit', handleSubmit);

    // Fix for mobile keyboard issues
    userInput.addEventListener('focus', () => {
        // On mobile, scroll the page after a small delay to keep input in view
        if (window.innerWidth <= 768) {
            setTimeout(() => {
                // Only scroll if the input is likely covered by keyboard
                const inputRect = userInput.getBoundingClientRect();
                if (inputRect.bottom > window.innerHeight * 0.6) {
                     window.scrollTo(0, document.body.scrollHeight);
                }
            }, 300);
        }
    });
    
    // Add event listener for clicking on citations
    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('citation-ref')) {
            const citationId = e.target.getAttribute('data-citation-id');
            const citationElement = document.getElementById(citationId);
            
            if (citationElement) {
                citationElement.scrollIntoView({ behavior: 'smooth' });
                citationElement.style.backgroundColor = 'var(--highlight-color)';
                citationElement.style.color = 'white';
                
                setTimeout(() => {
                    citationElement.style.backgroundColor = '';
                    citationElement.style.color = '';
                    citationElement.style.transition = 'background-color 0.3s ease, color 0.3s ease';
                }, 2000);
            }
        }
    });

    // Initial rendering of citation list (will show the placeholder)
    renderCitationHistory(qaCitationHistory);

    // Initial sync of toggles and labels to the default state
    // embeddingToggleDesktop.checked = currentEmbeddingType === "openai";
    // embeddingToggleMobile.checked = currentEmbeddingType === "openai";
    // updateToggleLabels(currentEmbeddingType);
});

// Particle effect code removed. 