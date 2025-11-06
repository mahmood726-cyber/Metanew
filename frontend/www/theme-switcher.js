// ==============================================================================
// THEME SWITCHER - Client-side theme management
// ==============================================================================
//
// Handles real-time theme updates without page reload
// Supports dark mode, font changes, and color customization
//
// ==============================================================================

// Google Fonts to load dynamically
const fontPairings = {
  inter: {
    base: 'Inter',
    heading: 'Inter',
    url: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap'
  },
  roboto_lora: {
    base: 'Roboto',
    heading: 'Lora',
    url: 'https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&family=Lora:wght@400;500;600;700&display=swap'
  },
  opensans_merriweather: {
    base: 'Open Sans',
    heading: 'Merriweather',
    url: 'https://fonts.googleapis.com/css2?family=Open+Sans:wght@300;400;600;700&family=Merriweather:wght@400;700;900&display=swap'
  },
  montserrat_sourceserif: {
    base: 'Montserrat',
    heading: 'Source Serif Pro',
    url: 'https://fonts.googleapis.com/css2?family=Montserrat:wght@300;400;600;700&family=Source+Serif+Pro:wght@400;600;700&display=swap'
  },
  poppins_crimson: {
    base: 'Poppins',
    heading: 'Crimson Text',
    url: 'https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&family=Crimson+Text:wght@400;600;700&display=swap'
  },
  worksans_spectral: {
    base: 'Work Sans',
    heading: 'Spectral',
    url: 'https://fonts.googleapis.com/css2?family=Work+Sans:wght@300;400;500;600;700&family=Spectral:wght@400;500;600;700&display=swap'
  }
};

// Initialize on page load
$(document).ready(function() {
  // Load saved preferences from localStorage
  loadSavedPreferences();

  // Add smooth scroll behavior
  $('html').css('scroll-behavior', 'smooth');
});

// Load saved theme preferences
function loadSavedPreferences() {
  const darkMode = localStorage.getItem('darkMode') === 'true';
  const fontPairing = localStorage.getItem('fontPairing') || 'inter';
  const primaryColor = localStorage.getItem('primaryColor');

  if (darkMode) {
    $('body').addClass('dark-mode');
    $('#theme_customizer-dark_mode_toggle').prop('checked', true);
  }

  if (fontPairing) {
    updateFonts(fontPairing);
  }

  if (primaryColor) {
    updatePrimaryColor(primaryColor);
  }
}

// Handle theme updates from Shiny
Shiny.addCustomMessageHandler('update_theme', function(message) {
  if (message.custom) {
    updatePrimaryColor(message.primary);
    localStorage.setItem('primaryColor', message.primary);
  } else {
    // Full theme change
    console.log('Applying theme:', message.bootswatch);
    // In a full app, we'd reload with new bootswatch
    // For now, just update primary color
    if (message.primary) {
      updatePrimaryColor(message.primary);
      localStorage.setItem('primaryColor', message.primary);
    }
  }
});

// Handle dark mode toggle
Shiny.addCustomMessageHandler('toggle_dark_mode', function(message) {
  if (message.enabled) {
    $('body').addClass('dark-mode');
    localStorage.setItem('darkMode', 'true');

    // Add animation
    $('body').css('transition', 'background-color 0.5s ease, color 0.5s ease');
  } else {
    $('body').removeClass('dark-mode');
    localStorage.setItem('darkMode', 'false');
  }
});

// Handle font updates
Shiny.addCustomMessageHandler('update_fonts', function(message) {
  updateFonts(message.pairing);
  localStorage.setItem('fontPairing', message.pairing);
});

// Update fonts function
function updateFonts(pairing) {
  const fonts = fontPairings[pairing];
  if (!fonts) return;

  // Load Google Font if not already loaded
  if (!$(`link[href="${fonts.url}"]`).length) {
    $('head').append(`<link href="${fonts.url}" rel="stylesheet">`);
  }

  // Apply fonts
  $('body').css('font-family', `"${fonts.base}", sans-serif`);
  $('h1, h2, h3, h4, h5, h6, .h1, .h2, .h3, .h4, .h5, .h6').css('font-family', `"${fonts.heading}", serif`);
}

// Update primary color
function updatePrimaryColor(color) {
  // Update CSS variables
  $(':root').css('--bs-primary', color);
  $(':root').css('--bs-primary-rgb', hexToRgb(color));

  // Update primary buttons
  $('.btn-primary').css('background-color', color);
  $('.btn-primary').css('border-color', color);

  // Update links
  $('a:not(.btn)').css('color', color);

  // Update nav-link active state
  $('.nav-link.active').css('color', color);
  $('.nav-link.active').css('border-bottom-color', color);
}

// Helper: Convert hex to RGB
function hexToRgb(hex) {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ?
    `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}` :
    null;
}

// Add micro-interactions
$(document).on('mouseenter', '.btn, .nav-link, .card', function() {
  $(this).css('transform', 'translateY(-2px)');
});

$(document).on('mouseleave', '.btn, .nav-link, .card', function() {
  $(this).css('transform', 'translateY(0)');
});

// Add fade-in animation for cards
$(document).ready(function() {
  $('.card').each(function(i) {
    $(this).css('opacity', '0');
    setTimeout(() => {
      $(this).css({
        'opacity': '1',
        'transition': 'opacity 0.5s ease'
      });
    }, i * 50);
  });
});
