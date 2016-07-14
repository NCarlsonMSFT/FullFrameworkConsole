using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ConsoleApplication1
{
    class Program
    {
        static void Main(string[] args)
        {
            // Some pointless busywork to make the app a little interesting
            Random r = new Random();
            int lowerBound = 1;
            int upperBound = 100000;

            int secret = r.Next(lowerBound, upperBound);
            Console.WriteLine($"I'm thinkg of a number between {lowerBound} and {upperBound - 1}");

            int guess = r.Next(lowerBound, upperBound);
            int guessCount = 1;
            while (true)
            {
                Console.WriteLine($"For guess {guessCount} i pick {guess}");
                if(guess == secret)
                {
                    Console.WriteLine($"I got it! And it only took me {guessCount} guesses.");
                    return;
                }
                else
                {
                    Console.WriteLine($"Drat, let me think...");
                    guess = r.Next(lowerBound, upperBound);
                    guessCount += 1;
                }
            }
        }
    }
}
